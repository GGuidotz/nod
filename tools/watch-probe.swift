// Prova la conferma col Watch da un processo firmato Apple (l'interprete Swift di Xcode), dal Terminale:
//   xcrun swift tools/watch-probe.swift            companion (solo Watch)
//   xcrun swift tools/watch-probe.swift both       Touch ID o Watch
// Se così il Watch riceve la richiesta e da Nod no, macOS rifiuta il Watch per la firma locale di Nod (senza Team ID).

import Foundation
import LocalAuthentication

let both = CommandLine.arguments.dropFirst().first == "both"
let policy: LAPolicy
if #available(macOS 15.0, *) {
    policy = both ? .deviceOwnerAuthenticationWithBiometricsOrCompanion : .deviceOwnerAuthenticationWithCompanion
} else {
    policy = both ? .deviceOwnerAuthenticationWithBiometricsOrWatch : .deviceOwnerAuthenticationWithWatch
}

let context = LAContext()
var error: NSError?
guard context.canEvaluatePolicy(policy, error: &error) else {
    print("policy \(policy.rawValue): cannot evaluate (\(error?.code ?? 0) \(error?.localizedDescription ?? ""))")
    exit(1)
}
print("policy \(policy.rawValue): asking… double-click the Watch side button")
let start = Date()
context.evaluatePolicy(policy, localizedReason: "test the Apple Watch (Nod watch-probe)") { ok, error in
    let seconds = String(format: "%.2f", Date().timeIntervalSince(start))
    if ok {
        print("confirmed after \(seconds)s")
    } else {
        let e = error as NSError?
        print("error after \(seconds)s: \(e?.code ?? 0) \(e?.localizedDescription ?? "")")
    }
    exit(ok ? 0 : 2)
}
RunLoop.main.run(until: Date().addingTimeInterval(60))
print("no answer in 60 s")
exit(3)
