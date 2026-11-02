import jetbrains.buildServer.configs.kotlin.*
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
// `TestFlight` and the single `Ship` were deleted on 2026-09-10 by leaving them
// out, when `Ship` became one configuration per platform; see task 38.
//
// **The five verification configurations hold no credential and must not gain
// one.** They build the public GitHub remote anonymously and pass
// `CODE_SIGNING_ALLOWED=NO`; the agent needs Xcode and a checkout, not a
// keychain. The two `Ship` configurations are the ones that use credentials,
// and they are separate.
//
// The settings VCS root is not declared here. `DslContext.settingsRoot` is
// whichever root the settings came from — `NoSpoilers_Main` — and turning
// versioned settings on makes that root read-only anyway (§8).

// **The four verification configurations carry their real `uuid`s, read off the
// server's own `config/projects/NoSpoilers/buildTypes/*.xml`.** TeamCity matches
// a DSL entity to an existing one by uuid first; without them it can decide
// these are new configurations, delete the old ones and start their build
// counters again — 93 builds of history when this file was written. `Ship iOS`
// and `Ship macOS` have none: this file created them, and an entity with no uuid
// is matched by its id. Do not invent one, and do not change their ids, or
// TeamCity deletes the configuration and its history and starts a new one.

// No lock: nothing here boots a simulator, and the server's one shared lock,
// `ios_simulator` on the Root project, is for legs that do (user decision,
// 2026-10-20). A leg added here that boots one takes `readLock("ios_simulator")`.
// `sharedResources` needs no import of its own; importing it explicitly did not
// compile on 2026-09-09.

// **Each configuration owns a directory by name, emptied before checkout and
// removed by the agent after the build, however it ends.** They would otherwise
// share one directory per agent, named after the VCS settings, with `tmp/`'s
// DerivedData and module caches carried from build to build. `cleanCheckout`
// deletes `.git` and ignored files too, so only the exact revision is left.
// Artifacts publish first: the default mode skips a cancelled or timed-out build,
// which would lose a stopped Ship's record, so `ALWAYS` is part of owning a
// workspace. The names are per configuration and each agent has its own work
// directory, so no two running builds can share one.
//
// **No build here needs an exception, and nothing in the directory is a cache.**
// What outlives a build sits outside it: the agent's git mirror under `system/git`,
// which is addressed by commit hash and cannot supply a generated file, and the
// login keychain, profiles and App Store Connect keys `Ship` signs with, which are
// persistent signing state. The project restores no other cache: it has no package
// dependencies.
fun BuildType.onTheAgent(workspace: String) {
    publishArtifacts = PublishMode.ALWAYS
    vcs {
        root(DslContext.settingsRoot)
        checkoutDir = "no-spoilers-$workspace"
        cleanCheckout = true
    }
    params {
        param("env.TMPDIR", "%system.teamcity.build.tempDir%")
        param("system.teamcity.build.checkoutDir.expireHours", "0")
    }
}

val verifyPython = BuildType {
    id("VerifyPython")
    uuid = "f3a71237-4c2e-4085-86b3-30b8c58829de"
    name = "Verify: Python"
    description = "scripts/verify-python-selftests.sh: the offline selftests of the six " +
        "App Store Connect scripts. Starts no Xcode, so it holds no lock and runs beside a compile."
    onTheAgent("verify-python")
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
        "the Mac app, the iOS app and the widget extension all compile, unsigned, and the two " +
        "apps again in Release, which is what Ship archives. One configuration rather than " +
        "three because they share one checkout and one agent."
    onTheAgent("verify-xcode")
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
        // The iOS app embeds the widget, so Release needs no third step.
        script {
            name = "mac release"
            scriptContent = "./scripts/verify-mac-build.sh -configuration Release"
        }
        script {
            name = "ios release"
            scriptContent = "./scripts/verify-ios-build.sh -configuration Release"
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
    onTheAgent("verify-swift-tests")
    artifactRules = "tmp/test-results => test-records"
    steps {
        script {
            name = "core"
            scriptContent = "./scripts/verify-core-tests.sh"
        }
    }
    // Generic rather than the typed builder: a wrong parameter finds no reports
    // and says so, where a wrong symbol stops the script compiling.
    features {
        feature {
            type = "xml-report-plugin"
            param("xmlReportParsing.reportType", "junit")
            param("xmlReportParsing.reportDirs", "+:tmp/test-results/*.xml")
            param("xmlReportParsing.verboseOutput", "true")
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
        "Verify: Xcode and Verify: Swift tests all passed on the same revision. Runs for every " +
        "push to main and nightly at 00:00 Europe/London. Neither ships anything."
    type = BuildTypeSettings.Type.COMPOSITE

    // No steps, no agent and no checkout. It exists so one light answers "did this
    // commit pass" without anyone reading three configurations.
    vcs {
        root(DslContext.settingsRoot)
        showDependenciesChanges = true
    }

    dependencies {
        // Two flags the server holds are left unset because they are already
        // TeamCity's defaults, and naming them does not compile: the REST value
        // `MAKE_FAILED_TO_START` for a dependency that failed to start is the
        // default of `onDependencyCancel` and is not a `FailureAction` constant,
        // and the VCS trigger's `DO_NOT_USE` quiet period is its default and
        // needs a type this file does not import. Both were tried on 2026-09-09
        // and both were compilation errors.
        //
        // **`reuseBuilds = NO` and the nightly are one decision, not two.** With
        // reuse allowed, a nightly at an already-built revision takes the last
        // green chain and reports success having compiled nothing — which is the
        // case the nightly exists for. ADD_PROBLEM rather than CANCEL so a red
        // leg leaves a red light rather than no light.
        snapshot(verifyPython) {
            onDependencyFailure = FailureAction.ADD_PROBLEM
            reuseBuilds = ReuseBuilds.NO
        }
        snapshot(verifyXcode) {
            onDependencyFailure = FailureAction.ADD_PROBLEM
            reuseBuilds = ReuseBuilds.NO
        }
        snapshot(verifySwiftTests) {
            onDependencyFailure = FailureAction.ADD_PROBLEM
            reuseBuilds = ReuseBuilds.NO
        }
    }

    // **`Verify` holds every trigger in this project, and nothing follows it.** A
    // push runs this chain at the pushed revision, and the nightly compiles an
    // unchanged repo. `Ship` is pressed by a person; see its own note.
    triggers {
        vcs {
            branchFilter = "+:<default>"
            triggerRules = """
                +:NoSpoilers/**
                +:NoSpoilersCore/**
                +:scripts/**
            """.trimIndent()
            perCheckinTriggering = true
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
            // A composite's nightly would otherwise take yesterday's legs and go
            // green having run nothing, whatever `reuseBuilds` says.
            enforceCleanCheckout = true
            enforceCleanCheckoutForDependencies = true
        }
    }
}

// TestFlight delivery, **one configuration per platform**. `ci-publish.sh`
// asserts what a build agent breaks and hands over to `submit_build.py`, which
// archives this exact revision, uploads it, waits for Apple, and delivers that
// build to the Internal testers. See docs/guides/building.md.
//
// **Two configurations rather than one `all` run, since 2026-09-10.** A macOS
// signing failure no longer turns the iPhone light red, either platform re-runs
// alone, and each has its own history. Each run reserves its own build number,
// so one commit reaches the two platforms under two numbers; Apple numbers the
// platforms separately and the approval tags are per platform, so nothing
// needs them equal. There is no recovery configuration: a delivery that could
// not finish names `testflight_distribute.py --build N` in its record, run from
// a machine holding the App Manager key, and the next run ships a newer build
// anyway. FunMax, which has one platform, has one `Ship` and no such button.
fun ship(platform: String, slug: String, label: String) = BuildType {
    id("Ship$slug")
    name = "Ship $label"
    description = "TestFlight for $label: scripts/ci-publish.sh --platform $platform --tested, which " +
        "asserts the agent and hands over to scripts/submit_build.py. Archives the verified " +
        "revision, uploads it, waits for Apple and delivers that exact build to the Internal " +
        "testers. Manual only: nothing triggers it, so it runs when a person presses it. ship.args takes --check or " +
        "--archive-only."
    onTheAgent("ship-$platform")

    params {
        // Goes back to empty after a custom run: `publish.args` left holding a
        // stale value is how four presses on 2026-09-05 each uploaded a version
        // Apple had already approved.
        param("ship.args", "")
    }

    steps {
        script {
            name = "ship"
            // `--tested` is true only because of the snapshot dependency on
            // `Verify` below, which is why it is spelled here and nowhere else.
            scriptContent = "scripts/ci-publish.sh --platform $platform --tested %ship.args%"
        }
    }

    // The run's record, and the export's own logs, which hold Apple's verbatim
    // answer when signing or an upload is refused. Xcode writes those logs to the
    // per-user temp directory and ignores TMPDIR, so `submit_build.py` copies them
    // into the run's directory; a rule on the build temp directory itself matched
    // nothing on Ship #8, the one run that needed it. The trailing `/**` matters:
    // a bundle is a directory, and a wildcard that ends at a directory name
    // matches no files, which is how Ship #9 kept the bundle and published none.
    artifactRules = """
        %system.teamcity.build.tempDir%/no-spoilers-ship/*/record.json => ship
        %system.teamcity.build.tempDir%/no-spoilers-ship/*/*.xcdistributionlogs/** => ship/distribution-logs
    """.trimIndent()

    // `reuseBuilds = SUCCESSFUL` rather than `NO`: the point is to ship a
    // revision the chain already proved, not to prove it again.
    dependencies {
        snapshot(verify) {
            onDependencyFailure = FailureAction.CANCEL
            reuseBuilds = ReuseBuilds.SUCCESSFUL
        }
    }

    failureConditions {
        // Above `submit_build.py`'s own worst case, so the script's bounds are
        // always what ends a run and it always records why: 40 minutes to
        // archive, 40 to export and upload, an hour of Apple and 10 to deliver,
        // plus half an hour outside those steps, is 180. The other 30 are for
        // the record. `submit_build.py --selftest` reads this number and fails
        // if it falls under that.
        executionTimeoutMin = 210
    }

    // One delivery of this platform at a time. A second would be refused its
    // build number by the tag push rather than collide, but it would queue two
    // archives for nothing.
    maxRunningBuilds = 1

    // **Manual only, since 2026-10-31: this configuration has no trigger, and
    // must not gain one.** A delivery happens because a person pressed `Ship`
    // (user decision). The snapshot dependency holds each press to a green `Verify`
    // at that revision, and a red one cancels the run. Unattended delivery ran from
    // 2026-10-11 to 2026-10-31, the last two weeks of it on a VCS trigger here.

    requirements {
        exists("tools.xcode.home")
    }
}

// Their ids are their history: see the uuid note at the top.
val shipIos = ship("ios", "Ios", "iOS")
val shipMacos = ship("macos", "Macos", "macOS")

project {
    description = "Native iPhone, macOS and WidgetKit race-weekend timelines."

    buildType(verifyPython)
    buildType(verifyXcode)
    buildType(verifySwiftTests)
    buildType(verify)
    buildType(shipIos)
    buildType(shipMacos)
}
