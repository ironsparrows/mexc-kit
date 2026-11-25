#!/usr/bin/env python3
"""Stands in for `docc` in the documentation build, which sets it as the plugin's `DOCC_EXEC`.

`MexcKit` re-exports `MexcKitCore`, so its pages show the core's types too. The build's explicit modules don't read the
core's `.swiftdoc`, so `MexcKit`'s symbol graphs carry the core's symbols without their doc comments, and with their
declarations spelled differently. So before `docc` converts `MexcKit`, this replaces those symbols with the ones in the
core's own symbol graphs, and gives every symbol that names the core the name `MexcKit`. `MexcKit`'s own symbols, such
as its client, stay as they are.
"""
import glob
import json
import os
import sys

CORE = "MexcKitCore"
MODULE = "MexcKit"

arguments = sys.argv[1:]
package = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", ".."))
catalog = os.path.join(package, "Sources", MODULE, f"{MODULE}.docc")


def read(path):
    with open(path, encoding="utf-8") as file:
        return json.load(file)


def core_symbols():
    """The core's symbols by id, from the one folder that holds its symbol graphs."""
    folders = glob.glob(os.path.join(package, ".build/out/Products/*/*", f"{CORE}.symbolgraphs"))
    if len(folders) != 1:
        sys.exit(f"error: expected one folder of the core's symbol graphs, found {folders}")
    paths = glob.glob(os.path.join(folders[0], "*.symbols.json"))
    return {symbol["identifier"]["precise"]: symbol for path in paths for symbol in read(path)["symbols"]}


def named_for_the_site(symbol):
    """A symbol that names the core as the site shows it. `docc` leaves out a comment that names another module."""
    comment = symbol.get("docComment", {})
    if comment.get("module") == CORE:
        comment["module"] = MODULE
    extension = symbol.get("swiftExtension", {})
    if extension.get("extendedModule") == CORE:
        extension["extendedModule"] = MODULE
    return symbol


def module_of(path):
    """The module a symbol graph belongs to: `MexcKit` for `MexcKit.symbols.json` and `MexcKit@Swift.symbols.json`."""
    return os.path.basename(path).removesuffix(".symbols.json").split("@")[0]


if len(arguments) > 1 and arguments[0] == "convert":
    if "--additional-symbol-graph-dir" not in arguments:
        sys.exit("error: docc convert ran without --additional-symbol-graph-dir")
    folder = arguments[arguments.index("--additional-symbol-graph-dir") + 1]
    graphs = glob.glob(os.path.join(folder, "**", "*.symbols.json"), recursive=True)
    module = [path for path in graphs if module_of(path) == MODULE]
    is_module = os.path.realpath(arguments[1]) == catalog
    if is_module and not module:
        sys.exit(f"error: no symbol graphs of {MODULE} in {folder}")
    symbols = core_symbols() if is_module else {}

    for path in graphs:
        graph = read(path)
        if is_module and path in module:
            graph["symbols"] = [symbols.get(symbol["identifier"]["precise"], symbol) for symbol in graph["symbols"]]
        graph["symbols"] = [named_for_the_site(symbol) for symbol in graph["symbols"]]
        with open(path, "w", encoding="utf-8") as file:
            json.dump(graph, file)

os.execvp("xcrun", ["xcrun", "docc", *arguments])
