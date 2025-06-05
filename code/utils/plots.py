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
        fig, ax = plt.subplots(figsize=(10, 2))
        palette = sns.color_palette('pastel', n_colors=len(segments))

        left = 0
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
            text_y = -bar_height / 2 - 0.15
            ax.text(
                center_x,
                text_y,
                seg,
                ha='center',
                va='top',
                fontsize=10,
                fontweight='bold'
            )
            ax.text(
                center_x,
                text_y - 0.12,
                f"{val/60:.1f} h",
                ha='center',
                va='top',
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
        plt.savefig(os.path.join(self.path, 'summary_plot'))
        plt.close()
        return None
    


    def day_plots(self,
                    act_cycles=['IN', 'LIG', 'MOD', 'VIG'],
                    sleep_col='dur_spt_min'):
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
        y_positions = range(len(self.df_day))

        fig, ax = plt.subplots(figsize=(10, 3 + 0.3 * len(self.df_day)))

        for i, row in self.df_day.iterrows():
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

            left = 0
            for cat, val in durations.items():
                ax.barh(
                    y=i,
                    width=val,
                    left=left,
                    height=bar_height,
                    color=colors[cat],
                    edgecolor='none'
                )

                # Compute center of this segment
                center_x = left + val / 2
                # Place the duration value beneath the bar (in hours)
                text_y = i - bar_height / 2 - 0.1
                if val > 1:
                    ax.text(
                        center_x,
                        text_y,
                        f"{val/60:.1f} h",
                        ha='center',
                        va='top',
                        fontsize=8
                    )
                left += val

                # Set y-tick labels using Day column if available, else use Day 1, Day 2, ...
            
            y_labels = [f"Day {i+1}" for i in range(len(self.df_day))]


        # Day labels
        ax.set_yticks(y_positions)
        ax.set_yticklabels(y_labels)

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
    Constructs a JSON of all PNG files organized by project, site, subject, and session,
    but only scans 'int' and 'obs' folders at the top level.
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

                master_data[project][site].setdefault(subject, {})

                for session_folder in os.listdir(subject_path):
                    session_path = os.path.join(subject_path, session_folder)
                    if not os.path.isdir(session_path):
                        continue
                    if not session_folder.startswith('ses-'):
                        continue

                    session_num = session_folder.replace('ses-', '')
                    png_files = [
                        os.path.join(session_path, fname)
                        for fname in os.listdir(session_path)
                        if fname.endswith('.png')
                    ]
                    png_files.sort()
                    master_data[project][site][subject][session_num] = png_files

    with open(out_file, 'w') as f:
        json.dump(master_data, f, indent=2)

    return master_data
