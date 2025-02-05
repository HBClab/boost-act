import os
import subprocess


class GG:
    def __init__(self, matched, intdir, obsdir):
        # Start an R session as a persistent subprocess.
        # We use --no-save and --slave for a non-interactive, quiet session.
        self.r_process = subprocess.Popen(
            ['R', '--no-save', '--slave'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        # Source the R requirements file in the R session.
        # The path to R_requirements.R is relative to the working directory.
        self.r_process.stdin.write("source('core/R_requirements.R')\n")
        self.r_process.stdin.flush()

        # Check for R errors
        stderr_output = self.r_process.stderr.read()
        if stderr_output.strip():
            raise RuntimeError(f"Error in sourcing R script: {stderr_output}")
        self.matched = matched
        self.INTDIR = intdir
        self.OBSDIR = obsdir

    def run_gg(self):
        for subject_id, records in self.matched.items():
            for record in records:
                study = record.get('study', 'default')
                file_path = record.get('file_path')
                # Extract the session from the record (assuming the key is 'run')
                session = record.get('run')

                if not file_path or not os.path.exists(file_path):
                    print(f"Invalid or missing file path for subject {subject_id}")
                    continue

                # Build the output directory based on study type.
                if study.lower() == 'obs':
                    outdir = os.path.join(self.OBSDIR, 'derivatives', 'GGIR-3.1.4',
                                          f"sub-{subject_id}_ses-{session}")
                else:
                    outdir = os.path.join(self.INTDIR, 'derivatives', 'GGIR-3.1.4',
                                          f"sub-{subject_id}_ses-{session}")

                try:
                    # Create the derivative subdirectory within outdir.
                    deriv_dir = os.path.join(outdir, 'derivatives')

                    # Construct the Rscript command.
                    command = (
                        f"Rscript core/basic_accel.R  --input_file {file_path} --output_location {outdir} --verbose"
                    )

                    # Run the command in a new subprocess.
                    result = subprocess.run(
                        command,
                        shell=True,
                        check=True,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE
                    )
                    # Decode and print the output.
                    print(f"Command output: {result.stdout.decode().strip()}")
                except subprocess.CalledProcessError as e:
                    print(f"Command failed for subject {subject_id} with exit status: {e.returncode}")
                    print(f"Error output: {e.stderr.decode().strip()}")

        # Once processing is complete, gracefully close the R subprocess.
        self.close_r_process()

    def close_r_process(self):
        if self.r_process and self.r_process.poll() is None:  # Check if process is still running
            try:
                self.r_process.stdin.write("q('no')\n")
                self.r_process.stdin.flush()
                self.r_process.stdin.close()
            except (BrokenPipeError, IOError):
                print("Attempted to close an already closed R process.")
            finally:
                self.r_process.wait()
                self.r_process = None

