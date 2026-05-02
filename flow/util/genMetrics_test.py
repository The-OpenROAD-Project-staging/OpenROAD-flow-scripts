#!/usr/bin/env python3

import os
import shutil
import subprocess
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))

import genMetrics


class IsGitRepoTests(unittest.TestCase):
    """Tests is_git_repo()'s tolerance of a missing git binary."""

    def test_returns_false_when_git_not_on_path(self):
        """When git is absent from PATH, is_git_repo() must return False
        without raising (e.g. Nix builds, hermetic Bazel sandboxes)."""
        with mock.patch.object(genMetrics.shutil, "which", return_value=None):
            self.assertFalse(genMetrics.is_git_repo())
            self.assertFalse(genMetrics.is_git_repo(folder="/tmp"))


class ShutilWhichGitConsistencyTests(unittest.TestCase):
    """Cross-checks shutil.which("git") against actually invoking git, so
    we catch any environment (e.g. a stripped Nix sandbox) where the two
    disagree and is_git_repo()'s PATH probe would give the wrong answer."""

    def test_which_matches_git_version(self):
        which_result = shutil.which("git")
        try:
            output = subprocess.check_output(
                ["git", "--version"], stderr=subprocess.STDOUT, text=True
            )
        except FileNotFoundError:
            self.assertIsNone(
                which_result,
                "shutil.which found git but invoking it raised FileNotFoundError",
            )
            return

        self.assertIsNotNone(
            which_result,
            "git --version succeeded but shutil.which returned None",
        )
        self.assertTrue(output.startswith("git version "), output)


class ShutilWhichMissingCommandTests(unittest.TestCase):
    """Validates shutil.which() returns None for a non-existent command.
    This is the primitive is_git_repo() relies on; if it ever returned a
    bogus path (in Nix, in a Bazel sandbox, anywhere) the missing-git
    branch would never fire."""

    BOGUS_CMD = "orfs-genmetrics-no-such-command-xyzzy"

    def test_which_returns_none_for_missing_command(self):
        self.assertIsNone(shutil.which(self.BOGUS_CMD))

    def test_invoking_missing_command_raises_file_not_found(self):
        with self.assertRaises(FileNotFoundError):
            subprocess.check_call([self.BOGUS_CMD])


if __name__ == "__main__":
    unittest.main()
