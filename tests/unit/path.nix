{ lib, fixtures }:
let
  path = lib.snowfall.path;
in
{
  split-file-extension = {
    testSimple = {
      expr = path.split-file-extension "file.nix";
      expected = [
        "file"
        "nix"
      ];
    };
    testUsesFinalExtension = {
      expr = path.split-file-extension "archive.tar.gz";
      expected = [
        "archive.tar"
        "gz"
      ];
    };
    testRejectsMissingExtension = {
      expr = (builtins.tryEval (path.split-file-extension "README")).success;
      expected = false;
    };
  };
  has-any-file-extension = {
    testHasExtension = {
      expr = path.has-any-file-extension "file.nix";
      expected = true;
    };
    testMissingExtension = {
      expr = path.has-any-file-extension "README";
      expected = false;
    };
    testPathCoercion = {
      expr = path.has-any-file-extension (fixtures.pure + "/alpha.nix");
      expected = true;
    };
  };
  get-file-extension = {
    testFinalExtension = {
      expr = path.get-file-extension "archive.tar.gz";
      expected = "gz";
    };
    testMissingExtension = {
      expr = path.get-file-extension "README";
      expected = "";
    };
  };
  has-file-extension = {
    testMatches = {
      expr = path.has-file-extension "nix" "file.nix";
      expected = true;
    };
    testDifferentExtension = {
      expr = path.has-file-extension "md" "file.nix";
      expected = false;
    };
    testNoExtension = {
      expr = path.has-file-extension "" "README";
      expected = false;
    };
  };
  get-parent-directory = {
    testNestedPath = {
      expr = path.get-parent-directory "/a/b/file.nix";
      expected = "b";
    };
    testRootChild = {
      expr = path.get-parent-directory "/file.nix";
      expected = "";
    };
  };
  get-file-name-without-extension = {
    testRemovesFinalExtension = {
      expr = path.get-file-name-without-extension "/a/archive.tar.gz";
      expected = "archive.tar";
    };
    testNoExtension = {
      expr = path.get-file-name-without-extension "/a/README";
      expected = "README";
    };
    testHiddenFile = {
      expr = path.get-file-name-without-extension "/a/.env";
      expected = "";
    };
  };
  get-output-name = {
    testDefaultModule = {
      expr = path.get-output-name (fixtures.pure + "/module/default.nix");
      expected = "module";
    };
    testRegularFileUsesParent = {
      expr = path.get-output-name (fixtures.pure + "/nested/text.md");
      expected = "nested";
    };
  };
  get-directory-name = {
    testDirectory = {
      expr = path.get-directory-name (fixtures.pure + "/nested");
      expected = "nested";
    };
    testTrailingSlash = {
      expr = path.get-directory-name "${fixtures.pure}/nested/";
      expected = "nested";
    };
  };
  get-relative-module-path = {
    testNestedDefault = {
      expr = path.get-relative-module-path "${fixtures.pure}" "${fixtures.pure}/nested/deeper/default.nix";
      expected = "nested/deeper";
    };
    testSourceWithoutLeadingRemainderSlash = {
      expr = path.get-relative-module-path "/different" "/module/default.nix";
      expected = "module";
    };
    testSourceItself = {
      expr = path.get-relative-module-path "${fixtures.pure}" "${fixtures.pure}/default.nix";
      expected = "";
    };
  };
}
