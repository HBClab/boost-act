import subprocess

class GG:
    """
    Class to execute GGIR processing for matched subject records.
    """

    def __init__(self, matched, intdir, obsdir):
        """
        Initialize the GG instance.

        Args:
            matched (dict): Mapping of subject IDs to their records.
            intdir (str): Path to the internal directory.
            obsdir (str): Path to the observational directory.
        """
        self.matched = matched
        self.INTDIR = intdir.rstrip('/') + '/'
        self.OBSDIR = obsdir.rstrip('/') + '/'
<<<<<<< HEAD
        self.DERIVATIVES = "derivatives/GGIR-3.2.6-test/"  # Defined within the class
=======
        self.DERIVATIVES = "derivatives/GGIR-3.2.6-test-ncp/"  # Defined within the class
>>>>>>> 980cb432186a05579a47e1f97a030b68b7e1c741

    def run_gg(self):
        """
        Run GGIR for both the internal and observational project directories.
        After each GGIR run, invoke the QC pipeline for that project.
        """
        # Assume QC is available at this import path
        from utils.qc import QC 

        for project_dir in [self.INTDIR, self.OBSDIR]:
            command = f"Rscript core/acc_new.R --project_dir {project_dir} --deriv_dir {self.DERIVATIVES}"

            try:
                # Execute the command in a new subprocess
                print(f"Running GGIR for project directory {project_dir}")
                process = subprocess.Popen(
                    command,
                    shell=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    bufsize=1,
                    universal_newlines=True
                )

                # Stream output line-by-line
                for line in process.stdout:
                    print(line, end='')  # already includes newline

                process.stdout.close()
                process.wait()

                if process.returncode != 0:
                    raise subprocess.CalledProcessError(process.returncode, command)

                print(f"GGIR completed successfully for {project_dir}.")

                # Determine project type for QC ('int' for internal, 'obs' for observational)
                if project_dir.rstrip('/') == self.INTDIR.rstrip('/'):
                    project_type = 'int'
                else:
                    project_type = 'obs'

                # Run QC for this project
                print(f"Starting QC pipeline for {project_type} project.")
                qc_runner = QC(project_type)
                qc_runner.qc()
                print(f"QC pipeline finished for {project_type} project.")

            except subprocess.CalledProcessError as e:
                print(f"Error running GGIR for {project_dir}: {e}")
                # Optionally, continue to next project or break, depending on desired behavior
            except Exception as e:
                print(f"Unexpected error when processing {project_dir}: {e}")
                # Optionally, continue to next project or break


