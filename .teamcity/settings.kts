import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildFeatures.sharedResources
import jetbrains.buildServer.configs.kotlin.buildSteps.script
import jetbrains.buildServer.configs.kotlin.triggers.schedule
import jetbrains.buildServer.configs.kotlin.triggers.vcs

version = "2026.1"

// The `No Spoilers` project, as code.
//
// **Every configuration this project has is here, and that is not optional.**
// With versioned settings on, the DSL is the whole truth: a configuration this
// file omits is a configuration TeamCity deletes. The four verification
// configurations and `TestFlight` existed in the UI first and were read back
// over the REST API before this file was written — steps, triggers, locks,
// agent requirements and every dependency flag — rather than reconstructed from
// what they look like from outside. `docs/TEAMCITY-AGENTS.md` §10 in
// `snowmonkey-proxy-common` is the tunnel that makes that read possible.
//
// **The five verification configurations hold no credential and must not gain
// one.** They build the public GitHub remote anonymously and pass
// `CODE_SIGNING_ALLOWED=NO`; the agent needs Xcode and a checkout, not a
// keychain. `Ship` is the one that holds credentials, and it is separate.
//
// The settings VCS root is not declared here. `DslContext.settingsRoot` is
// whichever root the settings came from — `NoSpoilers_Main` — and turning
// versioned settings on makes that root read-only anyway (§8).

// **The five existing configurations carry their real `uuid`s, read off the
// server's own `config/projects/NoSpoilers/buildTypes/*.xml`.** TeamCity matches
// a DSL entity to an existing one by uuid first; without them it can decide
// these are new configurations, delete the old ones and start their build
// counters again — 93 builds of history, and the `TestFlight` counter at 3.
// `Ship` has none because it does not exist yet, and TeamCity will assign it one.

val xcodeLock = "no-spoilers-xcode"

// Both Xcode legs take a *read* lock, so they run beside each other and only
// collide on the CPU. The quota below has to be at least as large as the number
// of legs holding one.
fun BuildType.sharesTheXcodeBox() {
    features {
        sharedResources {
            readLock(xcodeLock)
        }
    }
}

fun BuildType.onTheAgent() {
    vcs {
        root(DslContext.settingsRoot)
    }
    params {
        param("env.TMPDIR", "%system.teamcity.build.tempDir%")
    }
}

val verifyPython = BuildType {
    id("VerifyPython")
    uuid = "f3a71237-4c2e-4085-86b3-30b8c58829de"
    name = "Verify: Python"
    description = "scripts/verify-python-selftests.sh: the offline selftests of the six " +
        "App Store Connect scripts. Starts no Xcode, so it holds no lock and runs beside a compile."
    onTheAgent()
    steps {
        script {
            name = "selftests"
            scriptContent = "./scripts/verify-python-selftests.sh"
        }
    }
    requirements {
        exists("python3.executable")
    }
}

val verifyXcode = BuildType {
    id("VerifyXcode")
    uuid = "7dedfb93-073b-4518-a32c-d8502d321da8"
    name = "Verify: Xcode"
    description = "scripts/verify-mac-build.sh, verify-ios-build.sh and verify-widget-build.sh: " +
        "the Mac app, the iOS app and the widget extension all compile, unsigned. One " +
        "configuration rather than three because they queue behind the same Xcode lock anyway."
    onTheAgent()
    sharesTheXcodeBox()
    steps {
        script {
            name = "mac"
            scriptContent = "./scripts/verify-mac-build.sh"
        }
        script {
            name = "ios"
            scriptContent = "./scripts/verify-ios-build.sh"
        }
        script {
            name = "widget"
            scriptContent = "./scripts/verify-widget-build.sh"
        }
    }
    requirements {
        exists("tools.xcode.home")
    }
}

val verifySwiftTests = BuildType {
    id("VerifySwiftTests")
    uuid = "4a9e1beb-b9aa-4468-9c39-43005dc3652c"
    name = "Verify: Swift tests"
    description = "scripts/verify-core-tests.sh: the shared package's test suite. Deliberately " +
        "not downstream of Verify: Xcode; it is SwiftPM and builds its own sources, so a broken " +
        "Xcode target would hide a test result it cannot affect."
    onTheAgent()
    sharesTheXcodeBox()
    steps {
        script {
            name = "core"
            scriptContent = "./scripts/verify-core-tests.sh"
        }
    }
    requirements {
        exists("tools.xcode.home")
    }
}

val verify = BuildType {
    id("Verify")
    uuid = "694fdce7-693a-4880-9733-d999e7f6c1bc"
    name = "Verify"
    description = "The one light per commit. Runs nothing itself; green when Verify: Python, " +
        "Verify: Xcode and Verify: Swift tests all passed on the same revision. Triggered by " +
        "every push to main and nightly at 00:00 Europe/London."
    onTheAgent()

    // No steps. It exists so one light answers "did this commit pass" without
    // anyone reading three configurations.

    dependencies {
        // **`reuseBuilds = NO` and the nightly are one decision, not two.** With
        // reuse allowed, a nightly at an already-built revision takes the last
        // green chain and reports success having compiled nothing — which is the
        // case the nightly exists for. ADD_PROBLEM rather than CANCEL so a red
        // leg leaves a red light rather than no light.
        snapshot(verifyPython) {
            onDependencyFailure = FailureAction.ADD_PROBLEM
            onDependencyCancel = FailureAction.MAKE_FAILED_TO_START
            reuseBuilds = ReuseBuilds.NO
        }
        snapshot(verifyXcode) {
            onDependencyFailure = FailureAction.ADD_PROBLEM
            onDependencyCancel = FailureAction.MAKE_FAILED_TO_START
            reuseBuilds = ReuseBuilds.NO
        }
        snapshot(verifySwiftTests) {
            onDependencyFailure = FailureAction.ADD_PROBLEM
            onDependencyCancel = FailureAction.MAKE_FAILED_TO_START
            reuseBuilds = ReuseBuilds.NO
        }
    }

    triggers {
        vcs {
            branchFilter = "+:<default>"
            triggerRules = """
                +:NoSpoilers/**
                +:NoSpoilersCore/**
                +:scripts/**
            """.trimIndent()
            perCheckinTriggering = true
            quietPeriodMode = VcsTrigger.QuietPeriodMode.DO_NOT_USE
        }
        schedule {
            schedulingPolicy = daily {
                hour = 0
                minute = 0
                timezone = "Europe/London"
            }
            branchFilter = "+:<default>"
            triggerBuild = always()
            // The point is to build an unchanged repo, so this must not wait for
            // a change.
            withPendingChangesOnly = false
        }
    }
}

val testFlight = BuildType {
    id("TestFlight")
    uuid = "0c7571cc-7900-4dbd-ae9d-96caedce8cef"
    name = "TestFlight"
    description = "Sends the newest uploaded build on each platform to the Internal TestFlight " +
        "testers and writes its What to Test note: scripts/testflight_distribute.py --platform " +
        "ios, then --platform macos. Manual only. Builds nothing and holds no lock. " +
        "distribute.args takes --build N, --group NAME or --submit."
    vcs {
        root(DslContext.settingsRoot)
    }
    params {
        param("distribute.args", "")
    }
    steps {
        script {
            name = "iOS"
            scriptContent = "python3 scripts/testflight_distribute.py --platform ios --apply %distribute.args%"
        }
        script {
            name = "macOS"
            // Always, so a Mac build is never left stranded by an iPhone refusal.
            executionMode = BuildStep.ExecutionMode.ALWAYS
            scriptContent = "python3 scripts/testflight_distribute.py --platform macos --apply %distribute.args%"
        }
    }
}

// The release button. One press, one version, one build number, three channels:
// `ci-publish.sh --platform all` asserts what a build agent breaks and then
// hands over to `ship.sh`, which is already the thing that picks the version
// once and the build number once. See docs/guides/building.md.
val ship = BuildType {
    id("Ship")
    name = "Ship"
    description = "One press, one version, one build number: Mac App Store, Homebrew and the " +
        "iOS App Store. Runs scripts/ci-publish.sh --platform all, which asserts what a build " +
        "agent breaks and then hands over to scripts/ship.sh. Manual only. ship.args takes " +
        "--check or an explicit X.Y.Z."
    onTheAgent()

    // It archives twice, so it takes the write lock: no compile may run beside
    // a release, and no release beside a compile.
    features {
        sharedResources {
            writeLock(xcodeLock)
        }
    }

    params {
        // Empty by default, and it must be put back empty. `publish.args` left
        // holding a stale value is how four presses on 2026-09-05 each archived
        // and uploaded a version Apple had already approved.
        param("ship.args", "")
    }

    steps {
        script {
            name = "ship"
            scriptContent = "scripts/ci-publish.sh --platform all %ship.args%"
        }
    }

    // Unlike `TestFlight`, this one archives, so it must build a revision that
    // passed. `reuseBuilds = SUCCESSFUL` rather than `NO`: the point here is to
    // ship a commit the chain already proved, not to prove it again.
    dependencies {
        snapshot(verify) {
            onDependencyFailure = FailureAction.CANCEL
            reuseBuilds = ReuseBuilds.SUCCESSFUL
        }
    }

    failureConditions {
        // Two archives, two uploads, and an unbounded wait on Apple's notary
        // service in the middle of the second one.
        executionTimeoutMin = 120
    }

    // Only ever one release at a time. A second press during a run would take
    // the next build number from App Store Connect and race the first one's
    // tag push.
    maxRunningBuilds = 1

    // **No trigger, and that is the decision rather than an omission.** A
    // release is a person choosing to make one. Xcode Cloud archived and
    // uploaded on every push to `main`, which is how four days of an approved,
    // closed train were uploaded and refused by email without anyone deciding
    // anything. FunMax's `Ship` fires on every green `Verdict`; this one must
    // not.

    requirements {
        exists("tools.xcode.home")
    }
}

project {
    description = "Native iPhone, macOS and WidgetKit race-weekend timelines."

    // The Xcode lock. Quota 3 because a read lock takes one unit of it and the
    // two Xcode verification legs hold read locks; `Ship` takes the write lock
    // and so shuts both out, and they it.
    features {
        feature {
            id = "PROJECT_EXT_4"
            type = "JetBrains.SharedResources"
            param("name", xcodeLock)
            param("type", "quoted")
            param("quota", "3")
        }
    }

    buildType(verifyPython)
    buildType(verifyXcode)
    buildType(verifySwiftTests)
    buildType(verify)
    buildType(testFlight)
    buildType(ship)
}
