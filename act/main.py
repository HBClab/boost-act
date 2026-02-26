import argparse
import logging
import os


DEFAULT_SYSTEMS = ("vosslnx", "vosslnxft", "argon", "local")


def _configure_logging() -> None:

    log_file = os.getenv("LOG_FILE")
    handlers = []

    if log_file:

        log_dir = os.path.dirname(log_file)
        if log_dir:
            os.makedirs(log_dir, exist_ok=True)
        handlers.append(logging.FileHandler(log_file))

    else:
        handlers.append(logging.StreamHandler())

    logging.basicConfig(
        level=logging.INFO,
        format="[%(levelname)s] %(message)s",
        handlers=handlers,
    )


def _daysago_type(value: str) -> int:
    try:
        parsed = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("daysago must be an integer") from exc

    if parsed < 0:
        raise argparse.ArgumentTypeError("daysago must be non-negative")
    return parsed


def _token_type(value: str) -> str:
    if not value.strip():
        raise argparse.ArgumentTypeError("token must be a non-empty string")
    return value


def _available_systems() -> tuple[str, ...]:
    try:
        from act.utils.pipe import Pipe

        available = getattr(Pipe, "available_systems", None)
        if callable(available):
            return tuple(available())
    except Exception:
        pass

    return DEFAULT_SYSTEMS


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="python -m act.main",
        description=(
            "Run BOOST ingest pipeline using explicit typed arguments. "
            "Use --rebuild-manifest-only to rebuild manifest and skip GGIR/plotting."
        ),
    )
    parser.add_argument(
        "--token",
        type=_token_type,
        required=True,
        help="RedCap API token (required, non-empty)",
    )
    parser.add_argument(
        "--daysago",
        type=_daysago_type,
        required=True,
        help="Lookback window in days (required, integer >= 0)",
    )
    parser.add_argument(
        "--system",
        choices=_available_systems(),
        required=True,
        help="Target system path profile",
    )
    parser.add_argument(
        "--rebuild-manifest-only",
        action="store_true",
        help="Rebuild manifest-only mode (skips GGIR and plotting)",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    from act.utils.group import Group
    from act.utils.pipe import Pipe

    _configure_logging()
    args = build_parser().parse_args(argv)

    p = Pipe(
        token=args.token,
        daysago=args.daysago,
        system=args.system,
        rebuild_manifest_only=args.rebuild_manifest_only,
    )
    p.run_pipe()

    if not args.rebuild_manifest_only:
        Group(args.system).plot_person()
        Group(args.system).plot_session()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
