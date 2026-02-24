import subprocess
import logging

logger = logging.getLogger(__name__)


class GG:
    """
    Class to execute GGIR processing for matched subject records.
    """

    def __init__(self, matched, intdir, obsdir, system):
        """
        Initialize the GG instance.

        Args:
            matched (dict): Mapping of subject IDs to their records.
            intdir (str): Path to the internal directory.
            obsdir (str): Path to the observational directory.
        """
        self.matched = matched
        self.INTDIR = intdir.rstrip("/") + "/"
        self.OBSDIR = obsdir.rstrip("/") + "/"
        self.DERIVATIVES = "derivatives/GGIR-3.2.6/"  # Defined within the class
        self.system = system

    def run_gg(self):
        """
        Run GGIR for both the internal and observational project directories.
        After each GGIR run, invoke the QC pipeline for that project.
        """
        # Assume QC is available at this import path
        from code.utils.qc import QC

        for project_dir in [self.INTDIR, self.OBSDIR]:
            command = f"Rscript act/core/acc_new.R --project_dir {project_dir} --deriv_dir {self.DERIVATIVES}"

            try:
                # Execute the command in a new subprocess
                logger.info("Running GGIR for project directory %s", project_dir)
                process = subprocess.Popen(
                    command,
                    shell=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    bufsize=1,
                    universal_newlines=True,
                )

                # Stream output line-by-line
                for line in process.stdout:
                    logger.info(line.rstrip())

                process.stdout.close()
                process.wait()

                if process.returncode != 0:
                    raise subprocess.CalledProcessError(process.returncode, command)

                logger.info("GGIR completed successfully for %s.", project_dir)

                # Determine project type for QC ('int' for internal, 'obs' for observational)
                if project_dir.rstrip("/") == self.INTDIR.rstrip("/"):
                    project_type = "int"
                else:
                    project_type = "obs"

                # Run QC for this project
                logger.info("Starting QC pipeline for %s project.", project_type)
                qc_runner = QC(project_type, system=self.system)
                qc_runner.qc()
                logger.info("QC pipeline finished for %s project.", project_type)

            except subprocess.CalledProcessError:
                logger.exception("Error running GGIR for %s", project_dir)
                # optionally continue or break…
            except Exception:
                logger.exception("Unexpected error when processing %s", project_dir)
                # Optionally, continue to next project or break
