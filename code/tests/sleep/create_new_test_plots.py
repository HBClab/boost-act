import os
import glob
import pandas as pd
import plotly.graph_objects as go

class NewGroup:
    def __init__(self):
        self.obs_path = "/mnt/lss/Projects/BOOST/ObservationalStudy/3-experiment/data/act-obs-test"
        self.int_path = "/mnt/lss/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test"
        
        self.paths = [
            os.path.join(self.obs_path, 'derivatives', 'GGIR-3.2.6-test-ncp-sleep'),
            os.path.join(self.int_path, 'derivatives', 'GGIR-3.2.6-test-ncp-sleep')
        ]
        
        self.path = './plots'

    def _parse_person_file(self, file_path):
        print(f"\n[PARSE DEBUG] Opening file: {file_path}")
        try:
            df = pd.read_csv(file_path)
        except Exception as e:
            print(f"[PARSE ERROR] pd.read_csv failed: {e}")
            return None

        print(f"[PARSE DEBUG] Columns: {df.columns.tolist()}")
        print(f"[PARSE DEBUG] First few rows:\n{df.head(2)}")

        if df.empty:
            print(f"[PARSE WARNING] DataFrame is empty.")
            return None

        # your existing extraction logic…
        try:
            sleep = df["dur_spt_min_pla"].iloc[0]
            inactivity = df["dur_day_total_IN_min_pla"].iloc[0]
            light = df["dur_day_total_LIG_min_pla"].iloc[0]
            mod = df["dur_day_total_MOD_min_pla"].iloc[0]
            vig = df["dur_day_total_VIG_min_pla"].iloc[0]
        except KeyError as ke:
            print(f"[PARSE ERROR] Missing column: {ke}")
            return None

        mvpa = mod + vig
        total = sleep + inactivity + light + mvpa
        print(f"[PARSE DEBUG] Totals → sleep={sleep}, inact={inactivity}, light={light}, mvpa={mvpa}, total={total}")

        if total == 0:
            print(f"[PARSE WARNING] Total is zero, skipping.")
            return None

        session = df.get("filename", [""])[0].split("_")[-2] if "filename" in df else "unknown"
        return {
            "Sleep": sleep / total * 1440,
            "Inactivity": inactivity / total * 1440,
            "Light": light / total * 1440,
            "MVPA": mvpa / total * 1440,
            "Session": session
        }
    def plot_person(self):
        durations = []

        for base_dir in self.paths:
            print(f"\n[DEBUG] Checking base_dir: {base_dir!r}")
            print("  exists:", os.path.isdir(base_dir))
            try:
                entries = sorted(os.listdir(base_dir))
            except Exception as e:
                print("  ERROR listing directory:", e)
                continue

            print("  entries found:", entries)

            for entry in entries:
                print(f"    entry: {entry}")
                if not entry.startswith("sub-"):
                    print("      ➔ skipping, not a sub- folder")
                    continue

                # --- use glob instead of fixed filename ---
                results_dir = os.path.join(
                    base_dir, entry,
                    "accel", "output_accel", "results"
                )
                pattern = os.path.join(results_dir, "part5_personsummary_MM*.csv")
                matches = glob.glob(pattern)

                print(f"      looking in {results_dir!r}, found: {matches}")
                if not matches:
                    continue

                for person_file in matches:
                    print(f"      parsing file: {person_file!r}")
                    values = self._parse_person_file(person_file)
                    print("      parsed values:", values)
                    if not values:
                        continue

                    values["Subject"] = entry
                    durations.append(values)

        print(f"\n[DEBUG] Total records collected: {len(durations)}")
        if durations:
            print("Sample record:", durations[0])

        df_all = pd.DataFrame(durations)
        print("[DEBUG] df_all columns:", df_all.columns.tolist())

        if not df_all.empty and "Subject" in df_all.columns:
            df_all = df_all[~df_all["Subject"].str.startswith("sub-6")].reset_index(drop=True)
            df_all = df_all.sort_values("Subject").reset_index(drop=True)
        else:
            print("WARNING: No valid data found — skipping Subject filtering.")
            return   # bail out early so you don’t try to plot an empty df

        self._plot_stacked_bar(
            df_all,
            title="Normalized Average Activity Composition by Subject (All Sessions)",
            filename="avg_plot_all.html"
        )

    def plot_session(self):
        durations = []

        for base_dir in self.paths:
            print(f"\n[DEBUG] Checking base_dir: {base_dir!r}")
            print("  exists:", os.path.isdir(base_dir))
            try:
                entries = sorted(os.listdir(base_dir))
            except Exception as e:
                print("  ERROR listing directory:", e)
                continue

            print("  entries found:", entries)

            for entry in entries:
                print(f"    entry: {entry}")
                if not entry.startswith("sub-"):
                    print("      ➔ skipping, not a sub- folder")
                    continue

                subject_path = os.path.join(base_dir, entry, "accel")
                print(f"      subject_path: {subject_path!r}, exists:", os.path.isdir(subject_path))
                if not os.path.isdir(subject_path):
                    continue

                for session_folder in sorted(os.listdir(subject_path)):
                    print(f"        session_folder: {session_folder}")
                    if not session_folder.startswith("ses"):
                        print("          ➔ skipping, not a ses- folder")
                        continue

                    results_dir = os.path.join(
                        subject_path,
                        session_folder,
                        f"output_{session_folder}",
                        "results"
                    )
                    pattern = os.path.join(results_dir, "part5_personsummary_MM*.csv")
                    matches = glob.glob(pattern)

                    print(f"          looking in {results_dir!r}, found: {matches}")
                    if not matches:
                        continue

                    for person_file in matches:
                        print(f"          parsing file: {person_file!r}")
                        values = self._parse_person_file(person_file)
                        print("          parsed values:", values)
                        if not values:
                            continue

                        values["Subject"] = entry
                        values["Session"] = session_folder
                        durations.append(values)

        print(f"\n[DEBUG] Total records collected for sessions: {len(durations)}")
        if durations:
            print("Sample record:", durations[0])

        df_all = pd.DataFrame(durations)
        print("[DEBUG] df_all columns:", df_all.columns.tolist())

        if not df_all.empty and {"Subject", "Session"}.issubset(df_all.columns):
            df_all = df_all[~df_all["Subject"].str.startswith("sub-6")].reset_index(drop=True)
            df_all = df_all.sort_values(["Session", "Subject"]).reset_index(drop=True)
        else:
            print("WARNING: No valid data found — skipping Subject/Session filtering.")
            return

        for session, group_df in df_all.groupby("Session"):
            print(f"[DEBUG] Plotting session: {session}, {len(group_df)} records")
            self._plot_stacked_bar(
                group_df,
                title=f"Average Activity Composition — Session {session.upper()}",
                y_key="Subject",
                filename=f"avg_plot_{session}.html"
            )
    def _plot_stacked_bar(self, df, title, filename, y_key="Subject"):
        if df.empty:
            print("WARNING: No data to plot.")
            return

        activities = ["Sleep", "Inactivity", "Light", "MVPA"]
        colors = {
            "Sleep": "#A8DADC",
            "Inactivity": "#F1FAEE",
            "Light": "#FFD6A5",
            "MVPA": "#FF9F1C"
        }

        fig = go.Figure()
        for activity in activities:
            fig.add_trace(go.Bar(
                y=df[y_key],
                x=df[activity],
                name=activity,
                orientation='h',
                marker_color=colors[activity],
                hovertemplate=df[y_key] + f" - {activity} = " +
                              (df[activity] / 60).round(2).astype(str) + " hr<extra></extra>"
            ))

        fig.update_layout(
            barmode='stack',
            title=title,
            xaxis=dict(title="Hours (normalized to 24)"),
            yaxis=dict(title=y_key),
            height=30 * len(df),
            margin=dict(l=20, r=20, t=40, b=20),
            showlegend=True,
            autosize=True
        )
        os.makedirs(self.path, exist_ok=True)
        print(f"Writing plot to {os.path.join(self.path, filename)}")
        fig.write_html(os.path.join(self.path, filename))

