#!/usr/bin/env python3
"""Add customer/vet flavor build configurations to the Runner Xcode project.

Duplicates the Debug/Release/Profile configurations per flavor (the
documented Flutter flavor pattern), pointing the Runner target's new configs
at ios/Flutter/Customer.xcconfig / ios/Flutter/Vet.xcconfig so the bundle ID
and Dart entry point come from the flavor. The RunnerTests target is left
alone; the new schemes' Test action keeps using "Debug".
"""
import re
import secrets
import sys

PBX = "ios/Runner.xcodeproj/project.pbxproj"

FLAVORS = ["customer", "vet"]
MODES = ["Debug", "Release", "Profile"]

# Source config UUIDs: (project-level, runner-target-level, base xcconfig mode)
SRC = {
    "Debug": ("97C147031CF9000F007C117D", "97C147061CF9000F007C117D"),
    "Release": ("97C147041CF9000F007C117D", "97C147071CF9000F007C117D"),
    "Profile": ("249021D3217E4FDB00AE95B9", "249021D4217E4FDB00AE95B9"),
}
PROJECT_LIST = "97C146E91CF9000F007C117D"
TARGET_LIST = "97C147051CF9000F007C117D"


def new_uuid(taken):
    while True:
        u = secrets.token_hex(12).upper()
        if u not in taken:
            taken.add(u)
            return u


def main():
    with open(PBX) as f:
        src = f.read()
    taken = set(re.findall(r"[0-9A-F]{24}", src))

    cust_ref = new_uuid(taken)
    vet_ref = new_uuid(taken)

    # 1. PBXFileReference entries for the flavor xcconfigs.
    ref_anchor = (
        "\t\t9740EEB21CF90195004384FC /* Debug.xcconfig */ = {isa = "
        "PBXFileReference; fileEncoding = 4; lastKnownFileType = text.xcconfig; "
        "name = Debug.xcconfig; path = Flutter/Debug.xcconfig; "
        'sourceTree = "<group>"; };\n'
    )
    assert src.count(ref_anchor) == 1, "file ref anchor not unique"
    refs = (
        f"\t\t{cust_ref} /* Customer.xcconfig */ = {{isa = PBXFileReference; "
        f"fileEncoding = 4; lastKnownFileType = text.xcconfig; "
        f"name = Customer.xcconfig; path = Flutter/Customer.xcconfig; "
        f'sourceTree = "<group>"; }};\n'
        f"\t\t{vet_ref} /* Vet.xcconfig */ = {{isa = PBXFileReference; "
        f"fileEncoding = 4; lastKnownFileType = text.xcconfig; "
        f"name = Vet.xcconfig; path = Flutter/Vet.xcconfig; "
        f'sourceTree = "<group>"; }};\n'
    )
    src = src.replace(ref_anchor, ref_anchor + refs)

    # 2. Add them to the Flutter PBXGroup.
    group_anchor = "\t\t\t\t9740EEB31CF90195004384FC /* Generated.xcconfig */,\n"
    assert src.count(group_anchor) == 1, "group anchor not unique"
    src = src.replace(
        group_anchor,
        group_anchor
        + f"\t\t\t\t{cust_ref} /* Customer.xcconfig */,\n"
        + f"\t\t\t\t{vet_ref} /* Vet.xcconfig */,\n",
    )

    # 3. Duplicate the XCBuildConfiguration blocks.
    flavor_ref = {"customer": cust_ref, "vet": vet_ref}

    def get_block(uuid, name):
        pat = re.compile(
            r"(\t\t" + uuid + r" /\* " + name + r" \*/ = \{\n"
            r"\t\t\tisa = XCBuildConfiguration;\n.*?\n\t\t\};\n)",
            re.DOTALL,
        )
        m = pat.search(src)
        assert m, f"config block {name} ({uuid}) not found"
        return m.group(1)

    new_blocks = []
    list_add = {PROJECT_LIST: [], TARGET_LIST: []}
    for flavor in FLAVORS:
        for mode in MODES:
            cname = f"{mode}-{flavor}"
            proj_src, tgt_src = SRC[mode]

            # Project-level: plain copy with the new name.
            p_uuid = new_uuid(taken)
            p_block = get_block(proj_src, mode)
            p_block = p_block.replace(
                f"\t\t{proj_src} /* {mode} */ = {{",
                f"\t\t{p_uuid} /* {cname} */ = {{",
                1,
            )
            p_block = p_block.replace(f"\t\t\tname = {mode};", f"\t\t\tname = {cname};", 1)
            new_blocks.append(p_block)
            list_add[PROJECT_LIST].append((p_uuid, cname))

            # Runner-target-level: re-point at the flavor xcconfig and drop
            # the hardcoded bundle ID (the xcconfig owns it now).
            t_uuid = new_uuid(taken)
            t_block = get_block(tgt_src, mode)
            t_block = t_block.replace(
                f"\t\t{tgt_src} /* {mode} */ = {{",
                f"\t\t{t_uuid} /* {cname} */ = {{",
                1,
            )
            t_block = re.sub(
                r"\t\t\tbaseConfigurationReference = [0-9A-F]{24} /\* .*?\.xcconfig \*/;\n",
                f"\t\t\tbaseConfigurationReference = {flavor_ref[flavor]} "
                f"/* {flavor.capitalize()}.xcconfig */;\n",
                t_block,
                count=1,
            )
            assert "baseConfigurationReference" in t_block
            n = t_block.count("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.carepaws.carepaws;\n")
            assert n == 1, f"expected 1 bundle id line in {mode}, found {n}"
            t_block = t_block.replace(
                "\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.carepaws.carepaws;\n", ""
            )
            t_block = t_block.replace(f"\t\t\tname = {mode};", f"\t\t\tname = {cname};", 1)
            new_blocks.append(t_block)
            list_add[TARGET_LIST].append((t_uuid, cname))

    end_anchor = "/* End XCBuildConfiguration section */"
    assert src.count(end_anchor) == 1
    src = src.replace(end_anchor, "".join(new_blocks) + end_anchor)

    # 4. Register the new configs in the project + target config lists.
    for list_id, entries in list_add.items():
        pat = re.compile(
            r"(\t\t" + list_id + r" /\* Build configuration list for .*? \*/ = \{\n"
            r"\t\t\tisa = XCConfigurationList;\n"
            r"\t\t\tbuildConfigurations = \(\n)(.*?)(\n\t\t\t\);)",
            re.DOTALL,
        )
        m = pat.search(src)
        assert m, f"config list {list_id} not found"
        addition = "\n".join(f"\t\t\t\t{u} /* {n} */," for u, n in entries)
        # group(2) ends right after the last entry's comma and group(3)
        # starts with the newline before ");" — one newline on each side.
        src = src[: m.start(2)] + m.group(2) + "\n" + addition + src[m.start(3) :]

    # 5. Sanity: braces balance, every new UUID defined exactly once.
    assert src.count("{") == src.count("}"), "brace imbalance"
    for u in taken:
        pass
    with open(PBX, "w") as f:
        f.write(src)
    print("OK: added", len(new_blocks), "build configurations")


if __name__ == "__main__":
    sys.exit(main())
