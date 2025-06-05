import os
import json
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns


class ACT_PLOTS:

    def __init__(self, sub, ses, person, day):
        self.df_person = pd.read_csv(person) 
        self.df_day = pd.read_csv(day) 
        self.sub = str(sub).split('-')[1]
        self.ses = str(ses).split('-')[1]
        self.create_paths()
        print(self.sub, self.ses)


    def create_paths(self):
        if str(self.sub).startswith('9'):
            proj = 'int'
            site = 'NE'
            path = os.path.join('plots', proj, site, str(self.sub))
        elif str(self.sub).startswith('8'):
            proj = 'int'
            site = 'UI'
            path = os.path.join('plots', proj, site, str(self.sub))
        elif str(self.sub).startswith('7'):
            proj = 'obs'
            site = 'UI'
            path = os.path.join('plots', proj, site, str(self.sub))
        else:
            print("stupid NE and their dumb tests god...")
            proj = 'junk'
            path = os.path.join('plots', 'junk', str(self.sub))

        self.path = path
        os.makedirs(self.path, exist_ok=True)

        return None





    def summary_plot(self,
                     act_cycles=['IN', 'LIG', 'MOD', 'VIG'], 
                     sleep_col='dur_spt_min_pla'):
        """
        Plots a horizontal stacked bar of daily activity composition:
        Sleep, Inactivity, Light activity, MVPA, and Unidentified time (if any).
        """
        print("df_person type:", type(self.df_person))
        # Collect durations
        durations = {cycle: self.df_person[f'dur_day_total_{cycle}_min_pla'].iloc[0] for cycle in act_cycles}
        mvpa = durations.pop('MOD') + durations.pop('VIG')
        durations = {
            'Sleep': self.df_person[sleep_col].iloc[0],
            'Inactivity': durations['IN'],
            'Light': durations['LIG'],
            'MVPA': mvpa
        }
        total_minutes = 24 * 60
        identified = sum(durations.values())
        unidentified = total_minutes - identified
        if unidentified > 0:
            durations['Unidentified'] = unidentified

        # Order of segments
        segments = ['Sleep', 'Inactivity', 'Light', 'MVPA']
        if 'Unidentified' in durations:
            segments.append('Unidentified')
        values = [durations[s] for s in segments]

        # Styling
        sns.set_theme(style='whitegrid', rc={'axes.facecolor': 'white'})
        fig, ax = plt.subplots(figsize=(10, 3))
        palette = sns.color_palette('pastel', n_colors=len(segments))
        y_max = max(0.6 + 0.3, 0.5)  # max text_y + padding
        ax.set_ylim(-1, y_max)

        left = 0
        min_width_for_inside_label = 40  # in minutes

        for seg, val, color in zip(segments, values, palette):
            bar_height = 0.4
            ax.barh(
                y=0,
                width=val,
                left=left,
                height=0.5,
                color=color,
                edgecolor='black',
                linewidth=0.8
            )
            center_x = left + val / 2

            if val >= min_width_for_inside_label:
                text_y = -bar_height / 2 - 0.15
            else:
                text_y = 0.6  # move label above bar

            ax.text(
                center_x,
                text_y,
                seg,
                ha='center',
                va='bottom' if val < min_width_for_inside_label else 'top',
                fontsize=10,
                fontweight='bold'
            )
            ax.text(
                center_x,
                text_y + (0.12 if val < min_width_for_inside_label else -0.12),
                f"{val/60:.1f} h",
                ha='center',
                va='bottom' if val < min_width_for_inside_label else 'top',
                fontsize=9
            )

            left += val

        ax.set_xlim(0, total_minutes)
        ax.grid(False)  # ← disables gridlines
        ax.set_yticks([])
        ax.set_xticks([])
        ax.set_title('Average Daily Activity Composition (over the wear period)', fontsize=14, pad=12)
        ax.spines[['top', 'left', 'right', 'bottom']].set_visible(False)
        plt.tight_layout()
        plt.savefig(os.path.join(self.path, 'summary_plot'), bbox_inches='tight')
        plt.close()
        return None
    


    def day_plots(self,
                    act_cycles=['IN', 'LIG', 'MOD', 'VIG'],
                    sleep_col='dur_spt_sleep_min'):
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

        fig, ax = plt.subplots(figsize=(10, 3 + 0.3 * len(self.df_day)))
        y_spacing = 1.9
        y_positions = [i * y_spacing for i in range(len(self.df_day))]
        for i, row in self.df_day.iterrows():
            y_val = y_positions[i]
            # Build durations
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

            min_width_for_inside_label = 45  # minutes

            left = 0
            above_toggle = False  # NEW: start with below if needed

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

                if val >= min_width_for_inside_label:
                    text_y = y_val - bar_height / 2 - 0.1
                    va = 'top'
                else:
                    # Alternate above/below for short segments
                    if above_toggle:
                        text_y = y_val + bar_height / 2 + 0.05
                        va = 'bottom'
                    else:
                        text_y = y_val - bar_height / 2 - 0.25
                        va = 'top'
                    above_toggle = not above_toggle  # Flip toggle

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
                # Set y-tick labels using Day column if available, else use Day 1, Day 2, ...
            
            y_labels = [f"Day {i+1}" for i in range(len(self.df_day))]


        # Day labels
        ax.set_yticks(y_positions)
        ax.set_yticklabels(f"Day {i+1}" for i in range(len(self.df_day)))

        # Clean up axes
        ax.set_xticks([0, total_minutes/2, total_minutes])
        ax.set_xticklabels(["0 h", "12 h", "24 h"], fontsize=9)
        ax.spines[['top', 'right', 'left', 'bottom']].set_visible(False)
        ax.tick_params(axis='y', length=0)
        ax.set_xlim(0, total_minutes)

        # Legend
        handles = [plt.Rectangle((0, 0), 1, 1, color=colors[key]) for key in colors]
        labels = list(colors.keys())
        ax.legend(handles, labels, bbox_to_anchor=(1.01, 1), loc='upper left', frameon=False)

        fig.suptitle("Daily Activity Composition", fontsize=14, y=0.95)
        plt.tight_layout()
        plt.savefig(os.path.join(self.path, 'daily_plot'))
        plt.close()
        return None


def create_json(data_folder, out_file='data.json'):
    """
    Constructs a JSON of PNG files organized by project, site, and subject,
    assuming each subject folder contains exactly two PNG files.
    Only scans 'int' and 'obs' folders at the top level.
    """
    master_data = {}
    projects = ['int', 'obs']

    for project in projects:
        project_path = os.path.join(data_folder, project)
        if not os.path.isdir(project_path):
            continue

        master_data.setdefault(project, {})

        for site in os.listdir(project_path):
            site_path = os.path.join(project_path, site)
            if not os.path.isdir(site_path):
                continue

            master_data[project].setdefault(site, {})

            for subject in os.listdir(site_path):
                subject_path = os.path.join(site_path, subject)
                if not os.path.isdir(subject_path):
                    continue

                png_files = [
                    os.path.join(subject_path, fname).replace('plots/', 'data/', 1)
                    for fname in os.listdir(subject_path)
                    if fname.endswith('.png')
                ]
                png_files.sort()

                # Only include if there are exactly 2 PNGs
                if len(png_files) == 2:
                    master_data[project][site][subject] = png_files

    with open(out_file, 'w') as f:
        json.dump(master_data, f, indent=2)

    return master_data
