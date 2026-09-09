import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildSteps.script

version = "2026.1"

// The `Ship` button, as code.
//
// **This file describes ONE configuration and deliberately describes nothing
// else.** The four verification configurations and `TestFlight` are owned by
// the TeamCity UI and are not represented here, on purpose: versioned settings
// are authoritative, so a project synchronised against a DSL that omits a
// configuration *deletes* that configuration. Reproducing them here from the
// outside would mean guessing their triggers, timeouts, agent requirements and
// features, and a guess that compiles is indistinguishable from the truth until
// it has overwritten the thing it was guessing at.
//
// **So this must be attached to a NEW, EMPTY project, never to the existing
// one.** Create a project that contains nothing, point its versioned settings
// at this repository, and let it hold `Ship` alone. Enabling synchronisation on
// the project that currently holds the verification chain would destroy that
// chain. See tasks/36-teamcity-replaces-xcode-cloud.md.
//
// If the UI-owned configurations are ever to become code too, the way to do it
// is to let TeamCity generate their DSL — enable versioned settings on that
// project with no `.teamcity/settings.kts` present and it commits an exact
// representation of what exists — and then merge that generated file with this
// one. It is not something to write by hand from the outside.

// **No trigger, and that is the decision, not an omission.** A release is a
// person choosing to make one. The Xcode Cloud path archived and uploaded on
// every push to `main`, which is how four days of a closed train were uploaded
// and refused by email without anyone deciding anything.
//
// **No snapshot dependency either, and that one is a trade.** A dependency on
// the verification chain would mean naming a configuration this file must not
// name. It costs less than it looks: `release.sh` runs `verify-core-tests.sh`
// itself as the release gate, before anything is archived, and there is
// deliberately no flag to skip it. The gate is in the engine rather than in the
// pipeline, which is where it has been since 2026-08-22 — the day it was found
// to have left the release path entirely when the CI that held it stopped.
val ship = BuildType {
    id("Ship")
    name = "Ship"
    description = "One press, one version, one build number: Mac App Store, " +
        "Homebrew and the iOS App Store. Runs scripts/ci-publish.sh, which asserts " +
        "what a build agent breaks and then hands over to scripts/ship.sh. See " +
        "docs/guides/building.md."

    vcs {
        root(DslContext.settingsRoot)
    }

    params {
        // Empty by default, and it must be put back empty. `publish.args` left
        // holding a stale value is how four presses on 2026-09-05 each archived
        // and uploaded a version Apple had already approved. `--check` goes here
        // to run the assertions and stop; an explicit `X.Y.Z` goes here to ship
        // a version other than the one App Store Connect implies.
        param("ship.args", "")
    }

    steps {
        script {
            name = "ship"
            scriptContent = "scripts/ci-publish.sh --platform all %ship.args%"
        }
    }

    failureConditions {
        // Two archives, two uploads, and a wait on Apple's notary service in
        // the middle of the second one. The notary wait is the unbounded part
        // and is not ours to bound.
        executionTimeoutMin = 120
    }

    // Only ever one release at a time. A second press while the first is still
    // running would take the next build number from App Store Connect and race
    // the first one's tag push.
    maxRunningBuilds = 1
}

project {
    description = "Releases No Spoilers. Holds credentials the verification " +
        "configurations must never hold."

    buildType(ship)
}
