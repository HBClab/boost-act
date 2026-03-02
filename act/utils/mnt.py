import os

"""
THIS FILE SYMBOLICALLY LINKS RDSS and LSS TO WORKING DIRECTORY
"""


def create_symlinks(target_dir="../mnt", system="vosslnx"):
    """
    Create symlinks to the system-specific mount points defined on Pipe.
    """
    from act.utils.pipe import Pipe

    os.makedirs(target_dir, exist_ok=True)

    system = system or "vosslnx"
    try:
        paths = Pipe.system_paths(system)
    except ValueError as exc:
        raise ValueError(
            f"Unknown system '{system}'. Available systems: {', '.join(Pipe.available_systems())}"
        ) from exc

    symlinks = {
        "int_dir": paths.get("INT_DIR"),
        "obs_dir": paths.get("OBS_DIR"),
        "rdss_dir": paths.get("RDSS_DIR"),
    }

    for link_name, target_path in symlinks.items():
        if not target_path:
            print(
                f"Skipping symlink for {link_name}: no path configured for system '{system}'."
            )
            continue

        link_path = os.path.join(target_dir, link_name)
        try:
            if os.path.lexists(link_path):
                os.remove(link_path)
            os.symlink(target_path, link_path)
            print(f"Created symlink: {link_path} -> {target_path}")
        except OSError as e:
            print(f"Failed to create symlink for {link_name}: {e}")
