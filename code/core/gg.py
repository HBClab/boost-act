import os
import subprocess
import sys

class GG:
    def __init__(self, matched, intdir, obsdir):
        self.matched = matched
        self.INTDIR = intdir
        self.OBSDIR = obsdir

    def run_gg(self):
        for subject_id, records in self.matched.items():
            for record in records:
                study = record.get('study')
                file_path = record.get('file_path')
                session = record.get('run')

                if not file_path or not os.path.exists(file_path):
                    print(f"Invalid or missing file path for subject {subject_id}")
                    continue

                # Build the output directory based on study type.
                if study.lower() == 'obs':
                    outdir = os.path.join(self.OBSDIR, 'derivatives', 'GGIR-3.1.4',
                                          f"sub-{subject_id}", "ses-{session}")
                else:
                    outdir = os.path.join(self.INTDIR, 'derivatives', 'GGIR-3.1.4',
                                          f"sub-{subject_id}", "ses-{session}")

                try:
                    # Create the derivative subdirectory within outdir.
                    deriv_dir = os.path.join(outdir, 'derivatives')

                    # Construct the Rscript command.
                    command = (
                        f"""
                        Rscript core/basic_accel.R  --input_file {file_path} --output_location {outdir} --verbose
                        """
                    )

                    # Run the command in a new subprocess.
                    print(f"running GGIR for {file_path}")
                    result = subprocess.run(
                        command,
                        check=True,
                        stdout=sys.stdout,
                        stderr=sys.stderr
                    )
                    # Decode and print the output.
                    print(f"Command output: {result.stdout.decode().strip()}")
                except subprocess.CalledProcessError as e:
                    print(f"Command failed for subject {subject_id} with exit status: {e.returncode}")
                    print(f"Error output: {e.stderr.decode().strip()}")

