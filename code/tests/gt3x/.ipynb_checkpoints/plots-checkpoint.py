import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

def day_plot(df_day,
             sleep_col='dur_spt_sleep_min',
             dates_col='calendar_date'):
    """
    Plots a horizontal stacked bar of daily activity composition:
    Sleep, Inactivity, Light, MVPA, and Unidentified time.
    Also places the duration (in hours) beneath each segment.
    Expects columns:
    dur_day_total_IN_min, dur_day_total_LIG_min,
    dur_day_total_MOD_min, dur_day_total_VIG_min, dur_spt_min
    and a 'Day' column for labeling.
    """

    # Define colors
    colors = {
        "Sleep": "#782D73",         # Soft blue
        "Inactivity": "#E57A44",    # Neutral light gray
        "Light": "#95D075",         # Muted green
        "MVPA": "#7A89C2",          # Soft coral red
        "Unidentified": "#B0B0B0"   # Medium gray
    }

    sns.set_theme(style="white")
    total_minutes = 24 * 60
    bar_height = 0.4

    fig, ax = plt.subplots(
        figsize=(10, 3 + 0.3 * len(df_day))
    )

    # --- 1) Compute custom y-positions with extra space between subjects ---
    # extract subject numbers from filename
    subject_nums = (
        df_day['filename']
        .str.extract(r'sub-(\d+)')[0]
        .astype(int)
    )
    default_space = 1.9
    extra_space = 0.8
    y_positions = []
    boundary_ys = []
    subject_changes = []
    current_y = 0.0

    for i, subj in enumerate(subject_nums):
        if i == 0:
            # first row
            y_positions.append(current_y)
        else:
            if subj != subject_nums.iat[i - 1]:
                # subject changed → add extra_space
                current_y += default_space + extra_space
                # record midpoint for dotted line
                boundary = current_y - (default_space + extra_space) / 2
                boundary_ys.append(boundary)
                # store subject number for labeling
                subject_changes.append((boundary, f"Subject {subj}"))
            else:
                # same subject → normal spacing
                current_y += default_space
            y_positions.append(current_y)
    master_durations = {}
    # --- 2) Plot each day's stacked bar at its computed y-position ---
    min_width_for_inside_label = 45  # minutes
    for i, (idx, row) in enumerate(df_day.iterrows()):
        y_val = y_positions[i]
        # build durations
        durations = {
            'Sleep': row[sleep_col],
            'Inactivity': row['dur_day_total_IN_min'],
            'Light': row['dur_day_total_LIG_min'],
            'MVPA': row['dur_day_total_MOD_min'] + row['dur_day_total_VIG_min']
        }
        identified = sum(durations.values())
        unidentified = total_minutes - identified
        if unidentified > 0:
            durations['Unidentified'] = unidentified
        # store durations for output
        filename = str([row['filename'],row[dates_col]])
        master_durations[filename] = durations

        left = 0.0
        above_toggle = False
        for cat, val in durations.items():
            ax.barh(
                y=y_val,
                width=val,
                left=left,
                height=bar_height,
                color=colors[cat],
                edgecolor='none'
            )
            center_x = left + val / 2
            # choose label position
            if val >= min_width_for_inside_label:
                text_y = y_val - bar_height / 2 - 0.1
                va = 'top'
            else:
                if above_toggle:
                    text_y = y_val + bar_height / 2 + 0.05
                    va = 'bottom'
                else:
                    text_y = y_val - bar_height / 2 - 0.25
                    va = 'top'
                above_toggle = not above_toggle

            if val > 1:
                ax.text(
                    center_x,
                    text_y,
                    f"{val/60:.1f} h",
                    ha='center',
                    va=va,
                    fontsize=8
                )
            left += val

    # Day labels on y-axis
    ax.set_yticks(y_positions)
    date_labels = df_day[dates_col].astype(str).str.replace(r'\s*00:00:00$', '', regex=True)
    ax.set_yticklabels(date_labels)

    # Add dotted lines between subjects and subject labels
    for b, label in subject_changes:
        ax.axhline(y=b, color='black', linestyle='--', linewidth=0.7)
        ax.text(
            total_minutes + 30,
            b,
            label,
            ha='left',
            va='center',
            fontsize=9,
            color='black'
        )

    # Clean up x-axis
    ax.set_xticks([0, total_minutes/2, total_minutes])
    ax.set_xticklabels(["0 h", "12 h", "24 h"], fontsize=9)
    ax.spines[['top', 'right', 'left', 'bottom']].set_visible(False)
    ax.tick_params(axis='y', length=0)
    ax.set_xlim(0, total_minutes + 100)  # Extended to accommodate labels

    # Legend
    handles = [plt.Rectangle((0, 0), 1, 1, color=colors[k]) for k in colors]
    ax.legend(handles, list(colors.keys()),
              bbox_to_anchor=(1.01, 1),
              loc='upper left',
              frameon=False)

    fig.suptitle("Daily Activity Composition", fontsize=14, y=0.95)
    plt.tight_layout()
    plt.savefig('gt3x_plot.png', dpi=300)
    return master_durations

df_day = pd.read_csv('/mnt/lss/Users/zak/out/output_ggir/results/part5_daysummary_MM_L44.8M100.6V428.8_T5A5.csv')
durations = day_plot(df_day)
df_durations = pd.DataFrame(durations)
df_durations.to_csv('gt3x_durations.csv', index=True)
