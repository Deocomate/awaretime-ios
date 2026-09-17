#!/usr/bin/env python3
"""Generates AwareTime.xcodeproj from the file layout in this repository.

The generated project is committed, so Xcode can open the repo directly with
no extra tooling. Re-run this script after adding, renaming or removing a
source file:

    python3 Tools/generate_xcodeproj.py

Object identifiers are derived from stable md5 keys, which keeps the diff of a
regenerated project readable.
"""

from __future__ import annotations

import hashlib
import pathlib
import re
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROJECT_NAME = "AwareTime"
PROJECT_DIR = ROOT / f"{PROJECT_NAME}.xcodeproj"

BUNDLE_ID_PREFIX = "com.deocomate"
APP_GROUP_ID = '"group.$(BUNDLE_ID_PREFIX).awaretime"'
MARKETING_VERSION = "1.0.0"
CURRENT_PROJECT_VERSION = "1"
DEPLOYMENT_TARGET = "16.0"
WIDGET_DEPLOYMENT_TARGET = "16.1"
SWIFT_VERSION = "5.0"

# --------------------------------------------------------------------------- #
# Shared source groupings
# --------------------------------------------------------------------------- #

# Pure model + persistence layer. No UI framework, so it is safe to compile
# into the memory-constrained DeviceActivity monitor extension.
SHARED_CORE = [
    "Shared/Support/AppGroup.swift",
    "Shared/Support/AwareTimeFormat.swift",
    "Shared/Models/InterventionLevel.swift",
    "Shared/Models/InterventionSettings.swift",
    "Shared/Models/InterventionEvent.swift",
    "Shared/Models/DayState.swift",
    "Shared/Models/MathChallenge.swift",
    "Shared/Models/ShieldPresentation.swift",
    "Shared/Store/SharedStore.swift",
]

# Pulls in SwiftUI / UIKit — kept out of the monitor and shield-action
# extensions, which have no UI of their own.
SHARED_UI = ["Shared/Support/BrandPalette.swift"]

# Pulls in ActivityKit.
SHARED_ACTIVITY = [
    "Shared/LiveActivity/AwareTimeActivityAttributes.swift",
    "Shared/LiveActivity/LiveActivityController.swift",
]

# Needs FamilyControls / ManagedSettings, therefore the Family Controls
# entitlement.
SHARED_FAMILY = [
    "Shared/Store/SelectionStore.swift",
    "Shared/Services/ShieldController.swift",
]

SHARED_NOTIFICATIONS = ["Shared/Services/NotificationScheduler.swift"]
SHARED_MONITORING = ["Shared/Services/MonitoringPlan.swift"]
SHARED_REPORT = ["Shared/Services/ReportContext.swift"]

APP_SOURCES = [
    "AwareTime/AwareTimeApp.swift",
    "AwareTime/Services/AuthorizationService.swift",
    "AwareTime/Services/MonitoringCoordinator.swift",
    "AwareTime/Services/DemoModeController.swift",
    "AwareTime/ViewModels/UsageViewModel.swift",
    "AwareTime/Views/RootView.swift",
    "AwareTime/Views/OnboardingView.swift",
    "AwareTime/Views/MainView.swift",
    "AwareTime/Views/SettingsView.swift",
    "AwareTime/Views/HistoryView.swift",
    "AwareTime/Views/AppPickerView.swift",
    "AwareTime/Views/Components/CardView.swift",
    "AwareTime/Views/Components/StatusPill.swift",
    "AwareTime/Views/Components/BannerView.swift",
    "AwareTime/Views/Components/LadderView.swift",
    "AwareTime/Views/Components/ShieldPreviewView.swift",
]

APP_EXTENSION = "com.apple.product-type.app-extension"


class Target:
    def __init__(
        self,
        name,
        product_type,
        bundle_suffix,
        info_plist,
        entitlements,
        sources,
        resources=None,
        deployment_target=DEPLOYMENT_TARGET,
        extra_settings=None,
    ):
        self.name = name
        self.product_type = product_type
        self.bundle_suffix = bundle_suffix
        self.info_plist = info_plist
        self.entitlements = entitlements
        self.sources = sources
        self.resources = resources or []
        self.deployment_target = deployment_target
        self.extra_settings = extra_settings or {}

    @property
    def is_app(self):
        return self.product_type == "com.apple.product-type.application"

    @property
    def product_name(self):
        return f"{self.name}.app" if self.is_app else f"{self.name}.appex"

    @property
    def product_file_type(self):
        return "wrapper.application" if self.is_app else '"wrapper.app-extension"'

    @property
    def bundle_identifier(self):
        base = "$(BUNDLE_ID_PREFIX).awaretime"
        return base if not self.bundle_suffix else f"{base}.{self.bundle_suffix}"


APP_TARGET = Target(
    name="AwareTime",
    product_type="com.apple.product-type.application",
    bundle_suffix="",
    info_plist="AwareTime/Info.plist",
    entitlements="AwareTime/AwareTime.entitlements",
    sources=(
        SHARED_CORE
        + SHARED_UI
        + SHARED_ACTIVITY
        + SHARED_FAMILY
        + SHARED_NOTIFICATIONS
        + SHARED_MONITORING
        + SHARED_REPORT
        + APP_SOURCES
    ),
    resources=["AwareTime/Assets.xcassets"],
    extra_settings={
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    },
)

EXTENSION_TARGETS = [
    Target(
        name="DeviceActivityMonitorExtension",
        product_type=APP_EXTENSION,
        bundle_suffix="monitor",
        info_plist="DeviceActivityMonitorExtension/Info.plist",
        entitlements="DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.entitlements",
        sources=(
            SHARED_CORE
            + SHARED_ACTIVITY
            + SHARED_FAMILY
            + SHARED_NOTIFICATIONS
            + SHARED_MONITORING
            + ["DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift"]
        ),
    ),
    Target(
        name="ShieldConfigurationExtension",
        product_type=APP_EXTENSION,
        bundle_suffix="shieldconfig",
        info_plist="ShieldConfigurationExtension/Info.plist",
        entitlements="ShieldConfigurationExtension/ShieldConfigurationExtension.entitlements",
        sources=(
            SHARED_CORE
            + SHARED_UI
            + SHARED_FAMILY
            + ["ShieldConfigurationExtension/ShieldConfigurationExtension.swift"]
        ),
        resources=["ShieldConfigurationExtension/Assets.xcassets"],
    ),
    Target(
        name="ShieldActionExtension",
        product_type=APP_EXTENSION,
        bundle_suffix="shieldaction",
        info_plist="ShieldActionExtension/Info.plist",
        entitlements="ShieldActionExtension/ShieldActionExtension.entitlements",
        sources=(
            SHARED_CORE
            + SHARED_ACTIVITY
            + SHARED_FAMILY
            + ["ShieldActionExtension/ShieldActionExtension.swift"]
        ),
    ),
    Target(
        name="DeviceActivityReportExtension",
        product_type=APP_EXTENSION,
        bundle_suffix="report",
        info_plist="DeviceActivityReportExtension/Info.plist",
        entitlements="DeviceActivityReportExtension/DeviceActivityReportExtension.entitlements",
        sources=(
            SHARED_CORE
            + SHARED_UI
            + SHARED_FAMILY
            + SHARED_REPORT
            + [
                "DeviceActivityReportExtension/AwareTimeReportExtension.swift",
                "DeviceActivityReportExtension/TotalActivityReport.swift",
                "DeviceActivityReportExtension/TotalActivityView.swift",
            ]
        ),
    ),
    Target(
        name="AwareTimeWidget",
        product_type=APP_EXTENSION,
        bundle_suffix="widget",
        info_plist="AwareTimeWidget/Info.plist",
        entitlements="AwareTimeWidget/AwareTimeWidget.entitlements",
        sources=(
            SHARED_CORE
            + SHARED_UI
            + SHARED_ACTIVITY
            + [
                "AwareTimeWidget/AwareTimeWidgetBundle.swift",
                "AwareTimeWidget/AwareTimeLiveActivity.swift",
                "AwareTimeWidget/AwareTimeStatusWidget.swift",
                "AwareTimeWidget/WidgetBackground.swift",
            ]
        ),
        resources=["AwareTimeWidget/Assets.xcassets"],
        deployment_target=WIDGET_DEPLOYMENT_TARGET,
        extra_settings={
            "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
            "ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME": "AccentColor",
        },
    ),
]

ALL_TARGETS = [APP_TARGET] + EXTENSION_TARGETS


# --------------------------------------------------------------------------- #
# Identifier + quoting helpers
# --------------------------------------------------------------------------- #

_used_ids: dict[str, str] = {}


def oid(key: str) -> str:
    """Deterministic 24-hex-character object id."""
    if key in _used_ids:
        return _used_ids[key]
    digest = hashlib.md5(key.encode("utf-8")).hexdigest().upper()[:24]
    # Guard against a collision between two different keys.
    salt = 0
    while digest in _used_ids.values():
        salt += 1
        digest = hashlib.md5(f"{key}#{salt}".encode("utf-8")).hexdigest().upper()[:24]
    _used_ids[key] = digest
    return digest


SAFE = re.compile(r"^[A-Za-z0-9_./$:-]+$")


def q(value) -> str:
    """Quotes a pbxproj value when required."""
    if isinstance(value, bool):
        return "YES" if value else "NO"
    text = str(value)
    if text == "":
        return '""'
    if SAFE.match(text):
        return text
    escaped = text.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def file_type(path: str) -> str:
    if path.endswith(".swift"):
        return "sourcecode.swift"
    if path.endswith(".plist"):
        return "text.plist.xml"
    if path.endswith(".entitlements"):
        return "text.plist.entitlements"
    if path.endswith(".xcassets"):
        return "folder.assetcatalog"
    if path.endswith(".md"):
        return "net.daringfireball.markdown"
    if path.endswith(".yml") or path.endswith(".yaml"):
        return "text.yaml"
    return "text"


# --------------------------------------------------------------------------- #
# Build settings
# --------------------------------------------------------------------------- #

COMMON_PROJECT_SETTINGS = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "APP_GROUP_ID": APP_GROUP_ID,
    "BUNDLE_ID_PREFIX": BUNDLE_ID_PREFIX,
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
    "CLANG_WARN_BOOL_CONVERSION": "YES",
    "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
    "CLANG_WARN_EMPTY_BODY": "YES",
    "CLANG_WARN_UNREACHABLE_CODE": "YES",
    "COPY_PHASE_STRIP": "NO",
    "CURRENT_PROJECT_VERSION": CURRENT_PROJECT_VERSION,
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "GCC_WARN_UNDECLARED_SELECTOR": "YES",
    "GCC_WARN_UNUSED_FUNCTION": "YES",
    "GCC_WARN_UNUSED_VARIABLE": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
    "MARKETING_VERSION": MARKETING_VERSION,
    "SDKROOT": "iphoneos",
    "DEAD_CODE_STRIPPING": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    # Keeps Swift 5 semantics: concurrency mismatches stay warnings.
    "SWIFT_STRICT_CONCURRENCY": "minimal",
    "SWIFT_VERSION": SWIFT_VERSION,
    "TARGETED_DEVICE_FAMILY": '"1,2"',
    "VERSIONING_SYSTEM": '"apple-generic"',
}

DEBUG_PROJECT_SETTINGS = {
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_TESTABILITY": "YES",
    "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": '("DEBUG=1", "$(inherited)")',
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
    "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
}

RELEASE_PROJECT_SETTINGS = {
    "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
    "ENABLE_NS_ASSERTIONS": "NO",
    "MTL_ENABLE_DEBUG_INFO": "NO",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "SWIFT_OPTIMIZATION_LEVEL": '"-O"',
    "VALIDATE_PRODUCT": "YES",
}


def target_settings(target: Target, configuration: str) -> dict:
    settings = {
        "CODE_SIGN_ENTITLEMENTS": q(target.entitlements),
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": CURRENT_PROJECT_VERSION,
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": q(target.info_plist),
        "IPHONEOS_DEPLOYMENT_TARGET": target.deployment_target,
        "MARKETING_VERSION": MARKETING_VERSION,
        "PRODUCT_BUNDLE_IDENTIFIER": q(target.bundle_identifier),
        "PRODUCT_NAME": '"$(TARGET_NAME)"',
        "SWIFT_EMIT_LOC_STRINGS": "YES",
    }

    if target.is_app:
        settings["LD_RUNPATH_SEARCH_PATHS"] = '("$(inherited)", "@executable_path/Frameworks")'
    else:
        settings["LD_RUNPATH_SEARCH_PATHS"] = (
            '("$(inherited)", "@executable_path/Frameworks", '
            '"@executable_path/../../Frameworks")'
        )
        settings["SKIP_INSTALL"] = "YES"

    settings.update({k: q(v) for k, v in target.extra_settings.items()})
    return settings


# --------------------------------------------------------------------------- #
# Group tree
# --------------------------------------------------------------------------- #

class GroupNode:
    def __init__(self, name, path=None):
        self.name = name
        self.path = path
        self.children: dict[str, GroupNode] = {}
        self.files: list[str] = []

    def add(self, relative_path: str):
        parts = relative_path.split("/")
        node = self
        for part in parts[:-1]:
            if part not in node.children:
                node.children[part] = GroupNode(part, part)
            node = node.children[part]
        node.files.append(relative_path)


def collect_files() -> list[str]:
    paths: set[str] = set()
    for target in ALL_TARGETS:
        paths.update(target.sources)
        paths.update(target.resources)
        paths.add(target.info_plist)
        paths.add(target.entitlements)
    return sorted(paths)


# --------------------------------------------------------------------------- #
# pbxproj emitter
# --------------------------------------------------------------------------- #

def build_pbxproj() -> str:
    all_files = collect_files()
    for path in all_files:
        if not (ROOT / path).exists():
            raise SystemExit(f"error: referenced file is missing: {path}")

    tree = GroupNode(PROJECT_NAME)
    for path in all_files:
        tree.add(path)

    lines: list[str] = []
    out = lines.append

    project_id = oid("project")
    main_group_id = oid("group:<root>")
    products_group_id = oid("group:Products")

    out("// !$*UTF8*$!")
    out("{")
    out("\tarchiveVersion = 1;")
    out("\tclasses = {")
    out("\t};")
    out("\tobjectVersion = 56;")
    out("\tobjects = {")

    # ---------------- PBXBuildFile ----------------
    out("")
    out("/* Begin PBXBuildFile section */")
    for target in ALL_TARGETS:
        for path in target.sources:
            bid = oid(f"buildfile:{target.name}:{path}")
            out(
                f"\t\t{bid} /* {pathlib.PurePath(path).name} in Sources */ = "
                f"{{isa = PBXBuildFile; fileRef = {oid('fileref:' + path)} "
                f"/* {pathlib.PurePath(path).name} */; }};"
            )
        for path in target.resources:
            bid = oid(f"buildfile:{target.name}:{path}")
            out(
                f"\t\t{bid} /* {pathlib.PurePath(path).name} in Resources */ = "
                f"{{isa = PBXBuildFile; fileRef = {oid('fileref:' + path)} "
                f"/* {pathlib.PurePath(path).name} */; }};"
            )
    for target in EXTENSION_TARGETS:
        bid = oid(f"embedfile:{target.name}")
        out(
            f"\t\t{bid} /* {target.product_name} in Embed Foundation Extensions */ = "
            f"{{isa = PBXBuildFile; fileRef = {oid('product:' + target.name)} "
            f"/* {target.product_name} */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};"
        )
    out("/* End PBXBuildFile section */")

    # ---------------- PBXContainerItemProxy ----------------
    out("")
    out("/* Begin PBXContainerItemProxy section */")
    for target in EXTENSION_TARGETS:
        out(f"\t\t{oid('proxy:' + target.name)} /* PBXContainerItemProxy */ = {{")
        out("\t\t\tisa = PBXContainerItemProxy;")
        out(f"\t\t\tcontainerPortal = {project_id} /* Project object */;")
        out("\t\t\tproxyType = 1;")
        out(f"\t\t\tremoteGlobalIDString = {oid('target:' + target.name)};")
        out(f"\t\t\tremoteInfo = {target.name};")
        out("\t\t};")
    out("/* End PBXContainerItemProxy section */")

    # ---------------- PBXCopyFilesBuildPhase ----------------
    out("")
    out("/* Begin PBXCopyFilesBuildPhase section */")
    out(f"\t\t{oid('embedphase')} /* Embed Foundation Extensions */ = {{")
    out("\t\t\tisa = PBXCopyFilesBuildPhase;")
    out("\t\t\tbuildActionMask = 2147483647;")
    out('\t\t\tdstPath = "";')
    out("\t\t\tdstSubfolderSpec = 13;")
    out("\t\t\tfiles = (")
    for target in EXTENSION_TARGETS:
        out(
            f"\t\t\t\t{oid('embedfile:' + target.name)} "
            f"/* {target.product_name} in Embed Foundation Extensions */,"
        )
    out("\t\t\t);")
    out('\t\t\tname = "Embed Foundation Extensions";')
    out("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    out("\t\t};")
    out("/* End PBXCopyFilesBuildPhase section */")

    # ---------------- PBXFileReference ----------------
    out("")
    out("/* Begin PBXFileReference section */")
    for path in all_files:
        name = pathlib.PurePath(path).name
        out(
            f"\t\t{oid('fileref:' + path)} /* {name} */ = {{isa = PBXFileReference; "
            f"lastKnownFileType = {file_type(path)}; path = {q(name)}; "
            f"sourceTree = \"<group>\"; }};"
        )
    for target in ALL_TARGETS:
        out(
            f"\t\t{oid('product:' + target.name)} /* {target.product_name} */ = "
            f"{{isa = PBXFileReference; explicitFileType = {target.product_file_type}; "
            f"includeInIndex = 0; path = {q(target.product_name)}; "
            f"sourceTree = BUILT_PRODUCTS_DIR; }};"
        )
    out("/* End PBXFileReference section */")

    # ---------------- PBXFrameworksBuildPhase ----------------
    out("")
    out("/* Begin PBXFrameworksBuildPhase section */")
    for target in ALL_TARGETS:
        out(f"\t\t{oid('frameworks:' + target.name)} /* Frameworks */ = {{")
        out("\t\t\tisa = PBXFrameworksBuildPhase;")
        out("\t\t\tbuildActionMask = 2147483647;")
        out("\t\t\tfiles = (")
        out("\t\t\t);")
        out("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        out("\t\t};")
    out("/* End PBXFrameworksBuildPhase section */")

    # ---------------- PBXGroup ----------------
    out("")
    out("/* Begin PBXGroup section */")

    def emit_group(node: GroupNode, key: str):
        group_id = oid(f"group:{key}")
        out(f"\t\t{group_id} /* {node.name} */ = {{")
        out("\t\t\tisa = PBXGroup;")
        out("\t\t\tchildren = (")
        for child_name in sorted(node.children):
            child = node.children[child_name]
            out(f"\t\t\t\t{oid(f'group:{key}/{child_name}')} /* {child.name} */,")
        for path in sorted(node.files, key=lambda p: pathlib.PurePath(p).name):
            out(f"\t\t\t\t{oid('fileref:' + path)} /* {pathlib.PurePath(path).name} */,")
        if key == "<root>":
            out(f"\t\t\t\t{products_group_id} /* Products */,")
        out("\t\t\t);")
        if node.path:
            out(f"\t\t\tpath = {q(node.path)};")
        else:
            out(f"\t\t\tname = {q(node.name)};")
        out('\t\t\tsourceTree = "<group>";')
        out("\t\t};")
        for child_name in sorted(node.children):
            emit_group(node.children[child_name], f"{key}/{child_name}")

    emit_group(tree, "<root>")

    out(f"\t\t{products_group_id} /* Products */ = {{")
    out("\t\t\tisa = PBXGroup;")
    out("\t\t\tchildren = (")
    for target in ALL_TARGETS:
        out(f"\t\t\t\t{oid('product:' + target.name)} /* {target.product_name} */,")
    out("\t\t\t);")
    out("\t\t\tname = Products;")
    out('\t\t\tsourceTree = "<group>";')
    out("\t\t};")
    out("/* End PBXGroup section */")

    # ---------------- PBXNativeTarget ----------------
    out("")
    out("/* Begin PBXNativeTarget section */")
    for target in ALL_TARGETS:
        out(f"\t\t{oid('target:' + target.name)} /* {target.name} */ = {{")
        out("\t\t\tisa = PBXNativeTarget;")
        out(
            f"\t\t\tbuildConfigurationList = {oid('configlist:target:' + target.name)} "
            f"/* Build configuration list for PBXNativeTarget \"{target.name}\" */;"
        )
        out("\t\t\tbuildPhases = (")
        out(f"\t\t\t\t{oid('sources:' + target.name)} /* Sources */,")
        out(f"\t\t\t\t{oid('frameworks:' + target.name)} /* Frameworks */,")
        out(f"\t\t\t\t{oid('resources:' + target.name)} /* Resources */,")
        if target.is_app:
            out(f"\t\t\t\t{oid('embedphase')} /* Embed Foundation Extensions */,")
        out("\t\t\t);")
        out("\t\t\tbuildRules = (")
        out("\t\t\t);")
        out("\t\t\tdependencies = (")
        if target.is_app:
            for extension in EXTENSION_TARGETS:
                out(f"\t\t\t\t{oid('dependency:' + extension.name)} /* PBXTargetDependency */,")
        out("\t\t\t);")
        out(f"\t\t\tname = {target.name};")
        out(f"\t\t\tproductName = {target.name};")
        out(
            f"\t\t\tproductReference = {oid('product:' + target.name)} "
            f"/* {target.product_name} */;"
        )
        out(f"\t\t\tproductType = {q(target.product_type)};")
        out("\t\t};")
    out("/* End PBXNativeTarget section */")

    # ---------------- PBXProject ----------------
    out("")
    out("/* Begin PBXProject section */")
    out(f"\t\t{project_id} /* Project object */ = {{")
    out("\t\t\tisa = PBXProject;")
    out("\t\t\tattributes = {")
    out("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    out("\t\t\t\tLastSwiftUpdateCheck = 1600;")
    out("\t\t\t\tLastUpgradeCheck = 1600;")
    out("\t\t\t\tTargetAttributes = {")
    for target in ALL_TARGETS:
        out(f"\t\t\t\t\t{oid('target:' + target.name)} = {{")
        out("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
        out("\t\t\t\t\t};")
    out("\t\t\t\t};")
    out("\t\t\t};")
    out(
        f"\t\t\tbuildConfigurationList = {oid('configlist:project')} "
        f"/* Build configuration list for PBXProject \"{PROJECT_NAME}\" */;"
    )
    out('\t\t\tcompatibilityVersion = "Xcode 14.0";')
    out("\t\t\tdevelopmentRegion = en;")
    out("\t\t\thasScannedForEncodings = 0;")
    out("\t\t\tknownRegions = (")
    out("\t\t\t\ten,")
    out("\t\t\t\tvi,")
    out("\t\t\t\tBase,")
    out("\t\t\t);")
    out(f"\t\t\tmainGroup = {main_group_id};")
    out(f"\t\t\tproductRefGroup = {products_group_id} /* Products */;")
    out('\t\t\tprojectDirPath = "";')
    out('\t\t\tprojectRoot = "";')
    out("\t\t\ttargets = (")
    for target in ALL_TARGETS:
        out(f"\t\t\t\t{oid('target:' + target.name)} /* {target.name} */,")
    out("\t\t\t);")
    out("\t\t};")
    out("/* End PBXProject section */")

    # ---------------- PBXResourcesBuildPhase ----------------
    out("")
    out("/* Begin PBXResourcesBuildPhase section */")
    for target in ALL_TARGETS:
        out(f"\t\t{oid('resources:' + target.name)} /* Resources */ = {{")
        out("\t\t\tisa = PBXResourcesBuildPhase;")
        out("\t\t\tbuildActionMask = 2147483647;")
        out("\t\t\tfiles = (")
        for path in target.resources:
            out(
                f"\t\t\t\t{oid(f'buildfile:{target.name}:{path}')} "
                f"/* {pathlib.PurePath(path).name} in Resources */,"
            )
        out("\t\t\t);")
        out("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        out("\t\t};")
    out("/* End PBXResourcesBuildPhase section */")

    # ---------------- PBXSourcesBuildPhase ----------------
    out("")
    out("/* Begin PBXSourcesBuildPhase section */")
    for target in ALL_TARGETS:
        out(f"\t\t{oid('sources:' + target.name)} /* Sources */ = {{")
        out("\t\t\tisa = PBXSourcesBuildPhase;")
        out("\t\t\tbuildActionMask = 2147483647;")
        out("\t\t\tfiles = (")
        for path in target.sources:
            out(
                f"\t\t\t\t{oid(f'buildfile:{target.name}:{path}')} "
                f"/* {pathlib.PurePath(path).name} in Sources */,"
            )
        out("\t\t\t);")
        out("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        out("\t\t};")
    out("/* End PBXSourcesBuildPhase section */")

    # ---------------- PBXTargetDependency ----------------
    out("")
    out("/* Begin PBXTargetDependency section */")
    for target in EXTENSION_TARGETS:
        out(f"\t\t{oid('dependency:' + target.name)} /* PBXTargetDependency */ = {{")
        out("\t\t\tisa = PBXTargetDependency;")
        out(f"\t\t\ttarget = {oid('target:' + target.name)} /* {target.name} */;")
        out(f"\t\t\ttargetProxy = {oid('proxy:' + target.name)} /* PBXContainerItemProxy */;")
        out("\t\t};")
    out("/* End PBXTargetDependency section */")

    # ---------------- XCBuildConfiguration ----------------
    out("")
    out("/* Begin XCBuildConfiguration section */")

    def emit_configuration(config_id, name, settings):
        out(f"\t\t{config_id} /* {name} */ = {{")
        out("\t\t\tisa = XCBuildConfiguration;")
        out("\t\t\tbuildSettings = {")
        for key in sorted(settings):
            out(f"\t\t\t\t{key} = {settings[key]};")
        out("\t\t\t};")
        out(f"\t\t\tname = {name};")
        out("\t\t};")

    project_debug = dict(COMMON_PROJECT_SETTINGS)
    project_debug.update(DEBUG_PROJECT_SETTINGS)
    project_release = dict(COMMON_PROJECT_SETTINGS)
    project_release.update(RELEASE_PROJECT_SETTINGS)

    emit_configuration(oid("config:project:Debug"), "Debug", project_debug)
    emit_configuration(oid("config:project:Release"), "Release", project_release)

    for target in ALL_TARGETS:
        for configuration in ("Debug", "Release"):
            emit_configuration(
                oid(f"config:target:{target.name}:{configuration}"),
                configuration,
                target_settings(target, configuration),
            )
    out("/* End XCBuildConfiguration section */")

    # ---------------- XCConfigurationList ----------------
    out("")
    out("/* Begin XCConfigurationList section */")
    out(
        f"\t\t{oid('configlist:project')} /* Build configuration list for "
        f"PBXProject \"{PROJECT_NAME}\" */ = {{"
    )
    out("\t\t\tisa = XCConfigurationList;")
    out("\t\t\tbuildConfigurations = (")
    out(f"\t\t\t\t{oid('config:project:Debug')} /* Debug */,")
    out(f"\t\t\t\t{oid('config:project:Release')} /* Release */,")
    out("\t\t\t);")
    out("\t\t\tdefaultConfigurationIsVisible = 0;")
    out("\t\t\tdefaultConfigurationName = Release;")
    out("\t\t};")
    for target in ALL_TARGETS:
        out(
            f"\t\t{oid('configlist:target:' + target.name)} /* Build configuration list "
            f"for PBXNativeTarget \"{target.name}\" */ = {{"
        )
        out("\t\t\tisa = XCConfigurationList;")
        out("\t\t\tbuildConfigurations = (")
        out(f"\t\t\t\t{oid(f'config:target:{target.name}:Debug')} /* Debug */,")
        out(f"\t\t\t\t{oid(f'config:target:{target.name}:Release')} /* Release */,")
        out("\t\t\t);")
        out("\t\t\tdefaultConfigurationIsVisible = 0;")
        out("\t\t\tdefaultConfigurationName = Release;")
        out("\t\t};")
    out("/* End XCConfigurationList section */")

    out("\t};")
    out(f"\trootObject = {project_id} /* Project object */;")
    out("}")
    return "\n".join(lines) + "\n"


# --------------------------------------------------------------------------- #
# Scheme + workspace
# --------------------------------------------------------------------------- #

def build_scheme() -> str:
    target_id = oid(f"target:{APP_TARGET.name}")
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target_id}"
               BuildableName = "{APP_TARGET.product_name}"
               BlueprintName = "{APP_TARGET.name}"
               ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "{APP_TARGET.product_name}"
            BlueprintName = "{APP_TARGET.name}"
            ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "{APP_TARGET.product_name}"
            BlueprintName = "{APP_TARGET.name}"
            ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""


WORKSPACE_DATA = f"""<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
"""


def main() -> None:
    pbxproj = build_pbxproj()

    if PROJECT_DIR.exists():
        shutil.rmtree(PROJECT_DIR)
    (PROJECT_DIR / "xcshareddata/xcschemes").mkdir(parents=True, exist_ok=True)
    (PROJECT_DIR / "project.xcworkspace/xcshareddata").mkdir(parents=True, exist_ok=True)

    (PROJECT_DIR / "project.pbxproj").write_text(pbxproj)
    (PROJECT_DIR / f"xcshareddata/xcschemes/{PROJECT_NAME}.xcscheme").write_text(build_scheme())
    (PROJECT_DIR / "project.xcworkspace/contents.xcworkspacedata").write_text(WORKSPACE_DATA)

    total_files = sum(len(t.sources) + len(t.resources) for t in ALL_TARGETS)
    print(f"wrote {PROJECT_DIR.relative_to(ROOT)}")
    print(f"  targets: {len(ALL_TARGETS)}  build files: {total_files}")


if __name__ == "__main__":
    main()
