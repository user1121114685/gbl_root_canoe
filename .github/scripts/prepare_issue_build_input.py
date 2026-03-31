#!/usr/bin/env python3

import os
import pathlib
import re
import shutil
import sys
import tarfile
import tempfile
import urllib.parse
import urllib.request
import zipfile


URL_RE = re.compile(r"https?://[^\s<>()]+")
ARCHIVE_SUFFIXES = (".zip", ".tar", ".tar.gz", ".tgz")


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    sys.exit(1)


def append_output(name: str, value: str) -> None:
    output_path = os.environ.get("GITHUB_OUTPUT")
    if not output_path:
        return
    with open(output_path, "a", encoding="utf-8") as handle:
        handle.write(f"{name}={value}\n")


def normalize_url(url: str) -> str:
    return url.rstrip(".,)")


def iter_urls(body: str) -> list[str]:
    return [normalize_url(url) for url in URL_RE.findall(body or "")]


def parsed_path(url: str) -> str:
    return urllib.parse.urlparse(url).path.lower()


def pick_source(urls: list[str]) -> tuple[str, str]:
    for url in urls:
        if pathlib.PurePosixPath(parsed_path(url)).name.lower() == "abl.efi":
            return "efi_url", url

    for url in urls:
        lower_path = parsed_path(url)
        if lower_path.endswith(ARCHIVE_SUFFIXES):
            return "archive_url", url

    fail(
        "No valid build input found in issue body. Provide a direct ABL.EFI link or an archive containing ABL.EFI."
    )


def download_file(url: str, destination: pathlib.Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "issue-build-workflow"})
    with urllib.request.urlopen(request) as response, open(destination, "wb") as handle:
        shutil.copyfileobj(response, handle)


def is_safe_member_path(member_name: str) -> bool:
    normalized = pathlib.PurePosixPath(member_name)
    if normalized.is_absolute():
        return False
    return ".." not in normalized.parts


def extract_zip(archive_path: pathlib.Path, destination: pathlib.Path) -> None:
    with zipfile.ZipFile(archive_path) as archive:
        for member in archive.infolist():
            if not is_safe_member_path(member.filename):
                fail(f"Unsafe path in zip archive: {member.filename}")
        archive.extractall(destination)


def extract_tar(archive_path: pathlib.Path, destination: pathlib.Path) -> None:
    with tarfile.open(archive_path, "r:*") as archive:
        for member in archive.getmembers():
            if not is_safe_member_path(member.name):
                fail(f"Unsafe path in tar archive: {member.name}")
        archive.extractall(destination)


def extract_archive(archive_path: pathlib.Path, destination: pathlib.Path) -> None:
    lower_name = archive_path.name.lower()
    if lower_name.endswith(".zip"):
        extract_zip(archive_path, destination)
        return
    if lower_name.endswith((".tar", ".tar.gz", ".tgz")):
        extract_tar(archive_path, destination)
        return
    fail(f"Unsupported archive type: {archive_path.name}")


def find_abl_efi(search_root: pathlib.Path) -> pathlib.Path:
    matches = sorted(
        path for path in search_root.rglob("*") if path.is_file() and path.name.lower() == "abl.efi"
    )
    if not matches:
        fail("No ABL.EFI file was found in the uploaded archive.")
    if len(matches) > 1:
        fail("Multiple ABL.EFI files were found in the uploaded archive. Keep only one.")
    return matches[0]


def main() -> None:
    issue_body = os.environ.get("ISSUE_BODY", "")
    destination = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "images/ABL.EFI")
    urls = iter_urls(issue_body)
    source_kind, source_url = pick_source(urls)

    destination.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_root = pathlib.Path(temp_dir)

        if source_kind == "efi_url":
            download_file(source_url, destination)
        else:
            archive_name = pathlib.PurePosixPath(parsed_path(source_url)).name or "build-input.zip"
            archive_path = temp_root / archive_name
            extract_root = temp_root / "extract"
            extract_root.mkdir(parents=True, exist_ok=True)

            download_file(source_url, archive_path)
            extract_archive(archive_path, extract_root)
            shutil.copy2(find_abl_efi(extract_root), destination)

    append_output("source_kind", source_kind)
    append_output("source_url", source_url)
    append_output("input_path", str(destination))
    print(f"Prepared build input at {destination}")


if __name__ == "__main__":
    main()
