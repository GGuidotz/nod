// Prova la conferma col Watch da osascript, un processo firmato Apple: se così il Watch riceve la richiesta e da Nod no,
// macOS rifiuta il Watch per la firma locale di Nod (senza Team ID).
//   osascript -l JavaScript /Applications/Nod.app/Contents/Resources/watch-probe.js [policy] [motivo]
// policy: il valore numerico di LAPolicy (Nod lo passa; 3 = companion/watch, 4 = Touch ID o Watch).
ObjC.import('Foundation');
ObjC.import('LocalAuthentication');

function run(argv) {
  const policy = parseInt(argv[0] || '3', 10);
  const reason = argv[1] || 'test the Apple Watch (Nod watch-probe)';
  const ctx = $.LAContext.alloc.init;
  const err = Ref();
  if (!ctx.canEvaluatePolicyError(policy, err)) {
    let code = '?';
    try { code = err[0].code; } catch (e) { /* nessun errore restituito */ }
    return 'osascript policy ' + policy + ': cannot evaluate (' + code + ')';
  }
  let result = null;
  const start = $.NSDate.date;
  ctx.evaluatePolicyLocalizedReasonReply(policy, $(reason), function (ok, error) {
    result = ok ? 'confirmed' : 'error ' + (error ? error.code + ' ' + ObjC.unwrap(error.localizedDescription) : '?');
  });
  const deadline = $.NSDate.dateWithTimeIntervalSinceNow(60);
  while (result === null && deadline.timeIntervalSinceNow > 0) {
    $.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(0.1));
  }
  const seconds = (-start.timeIntervalSinceNow).toFixed(2);
  return 'osascript policy ' + policy + ' after ' + seconds + 's: ' + (result === null ? 'no answer in 60 s' : result);
}
