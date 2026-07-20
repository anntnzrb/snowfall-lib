{ lib, fixtures }:
let
  fs = lib.snowfall.fs;
  root = fixtures.pure;
  missing = root + "/does-not-exist";
  names = builtins.map builtins.baseNameOf;
  relative = path: builtins.replaceStrings [ "${root}/" ] [ "" ] (toString path);
  relatives = builtins.map relative;
in
{
  is-file-kind = {
    testRegular = {
      expr = fs.is-file-kind "regular";
      expected = true;
    };
    testOther = {
      expr = fs.is-file-kind "directory";
      expected = false;
    };
  };
  is-symlink-kind = {
    testSymlink = {
      expr = fs.is-symlink-kind "symlink";
      expected = true;
    };
    testOther = {
      expr = fs.is-symlink-kind "regular";
      expected = false;
    };
  };
  is-directory-kind = {
    testDirectory = {
      expr = fs.is-directory-kind "directory";
      expected = true;
    };
    testOther = {
      expr = fs.is-directory-kind "unknown";
      expected = false;
    };
  };
  is-unknown-kind = {
    testUnknown = {
      expr = fs.is-unknown-kind "unknown";
      expected = true;
    };
    testOther = {
      expr = fs.is-unknown-kind "symlink";
      expected = false;
    };
  };

  get-file = {
    testAppendsRelativePath = {
      expr = lib.hasSuffix "/chosen/path" (fs.get-file "chosen/path");
      expected = true;
    };
    testEmptyPath = {
      expr = lib.hasSuffix "/" (fs.get-file "");
      expected = true;
    };
  };
  get-snowfall-file = {
    testAppendsRelativePath = {
      expr = lib.hasSuffix "/chosen/path" (fs.get-snowfall-file "chosen/path");
      expected = true;
    };
    testEmptyPath = {
      expr = lib.hasSuffix "/" (fs.get-snowfall-file "");
      expected = true;
    };
  };
  internal-get-file = {
    testAppendsRelativePath = {
      expr = lib.hasSuffix "/chosen/path" (fs.internal-get-file "chosen/path");
      expected = true;
    };
    testEmptyPath = {
      expr = lib.hasSuffix "/" (fs.internal-get-file "");
      expected = true;
    };
  };

  safe-read-directory = {
    testExisting = {
      expr = (fs.safe-read-directory root)."alpha.nix";
      expected = "regular";
    };
    testExistingKinds = {
      expr = builtins.intersectAttrs {
        "alpha.nix" = null;
        module = null;
      } (fs.safe-read-directory root);
      expected = {
        "alpha.nix" = "regular";
        module = "directory";
      };
    };
    testMissing = {
      expr = fs.safe-read-directory missing;
      expected = { };
    };
  };
  get-entries-by-kind = {
    testFiles = {
      expr = names (fs.get-entries-by-kind fs.is-file-kind root);
      expected = [
        "alpha.nix"
        "default.nix"
        "note.txt"
      ];
    };
    testDirectories = {
      expr = names (fs.get-entries-by-kind fs.is-directory-kind root);
      expected = [
        "module"
        "nested"
      ];
    };
    testNoMatches = {
      expr = fs.get-entries-by-kind (_: false) root;
      expected = [ ];
    };
  };
  get-directories = {
    testDirectories = {
      expr = names (fs.get-directories root);
      expected = [
        "module"
        "nested"
      ];
    };
    testMissing = {
      expr = fs.get-directories missing;
      expected = [ ];
    };
  };
  get-directories-with-default = {
    testFiltersDirectories = {
      expr = names (fs.get-directories-with-default root);
      expected = [ "module" ];
    };
    testMissing = {
      expr = fs.get-directories-with-default missing;
      expected = [ ];
    };
  };
  get-files = {
    testFiles = {
      expr = names (fs.get-files root);
      expected = [
        "alpha.nix"
        "default.nix"
        "note.txt"
      ];
    };
    testMissing = {
      expr = fs.get-files missing;
      expected = [ ];
    };
  };
  get-files-recursive = {
    testTraversal = {
      expr = relatives (fs.get-files-recursive root);
      expected = [
        "alpha.nix"
        "default.nix"
        "module/default.nix"
        "nested/deeper/beta.nix"
        "nested/deeper/default.nix"
        "nested/text.md"
        "note.txt"
      ];
    };
    testMissing = {
      expr = fs.get-files-recursive missing;
      expected = [ ];
    };
  };
  filter-files = {
    testPredicate = {
      expr = names (fs.filter-files (file: lib.hasSuffix ".txt" file) root);
      expected = [ "note.txt" ];
    };
    testRejectsAll = {
      expr = fs.filter-files (_: false) root;
      expected = [ ];
    };
  };
  filter-files-recursive = {
    testPredicate = {
      expr = relatives (
        fs.filter-files-recursive (file: lib.hasSuffix ".md" file) root
      );
      expected = [ "nested/text.md" ];
    };
    testRejectsAll = {
      expr = fs.filter-files-recursive (_: false) root;
      expected = [ ];
    };
  };
  get-nix-files = {
    testTopLevelOnly = {
      expr = names (fs.get-nix-files root);
      expected = [
        "alpha.nix"
        "default.nix"
      ];
    };
    testMissing = {
      expr = fs.get-nix-files missing;
      expected = [ ];
    };
  };
  get-nix-files-recursive = {
    testTraversal = {
      expr = relatives (fs.get-nix-files-recursive root);
      expected = [
        "alpha.nix"
        "default.nix"
        "module/default.nix"
        "nested/deeper/beta.nix"
        "nested/deeper/default.nix"
      ];
    };
    testMissing = {
      expr = fs.get-nix-files-recursive missing;
      expected = [ ];
    };
  };
  get-default-nix-files = {
    testTopLevel = {
      expr = names (fs.get-default-nix-files root);
      expected = [ "default.nix" ];
    };
    testNoMatch = {
      expr = fs.get-default-nix-files (root + "/nested");
      expected = [ ];
    };
  };
  get-default-nix-files-recursive = {
    testTraversal = {
      expr = relatives (fs.get-default-nix-files-recursive root);
      expected = [
        "default.nix"
        "module/default.nix"
        "nested/deeper/default.nix"
      ];
    };
    testMissing = {
      expr = fs.get-default-nix-files-recursive missing;
      expected = [ ];
    };
  };
  get-non-default-nix-files = {
    testTopLevel = {
      expr = names (fs.get-non-default-nix-files root);
      expected = [ "alpha.nix" ];
    };
    testNoMatch = {
      expr = fs.get-non-default-nix-files (root + "/module");
      expected = [ ];
    };
  };
  get-non-default-nix-files-recursive = {
    testTraversal = {
      expr = relatives (fs.get-non-default-nix-files-recursive root);
      expected = [
        "alpha.nix"
        "nested/deeper/beta.nix"
      ];
    };
    testMissing = {
      expr = fs.get-non-default-nix-files-recursive missing;
      expected = [ ];
    };
  };
}
