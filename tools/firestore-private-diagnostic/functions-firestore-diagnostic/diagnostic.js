'use strict';

const crypto = require('node:crypto');

const TRACE_ID = /^[0-9a-f]{32}$/;

function requestHeader(req, name) {
  if (typeof req.get === 'function') return req.get(name);
  return req.headers?.[name.toLowerCase()];
}

function correlationFor(req, {projectId, randomUUID = crypto.randomUUID} = {}) {
  const raw = requestHeader(req, 'x-cloud-trace-context');
  const candidate = typeof raw === 'string' ? raw.split('/')[0] : '';
  const traceId = TRACE_ID.test(candidate) ? candidate : undefined;
  const correlationId = traceId ?? randomUUID();
  const trace = traceId && projectId ? `projects/${projectId}/traces/${traceId}` : undefined;
  return {correlationId, 'logging.googleapis.com/trace': trace};
}

function audit(logger, severity, fields) {
  const entry = {severity, event: 'firestore_private_isolation_diagnostic', ...fields};
  const method = severity === 'ERROR' ? 'error' : 'info';
  logger[method](entry);
}

function createDiagnosticHandler({authenticate, runIsolationProof, logger = console, projectId, randomUUID}) {
  if (typeof authenticate !== 'function' || typeof runIsolationProof !== 'function') {
    throw new TypeError('authenticate and runIsolationProof are required');
  }
  return async function diagnostic(req, res) {
    const correlation = correlationFor(req, {projectId, randomUUID});
    res.set('Cache-Control', 'no-store');
    res.set('X-Diagnostic-Correlation-ID', correlation.correlationId);
    if (req.method !== 'POST') {
      audit(logger, 'INFO', {...correlation, outcome: 'method_not_allowed'});
      return res.status(405).json({ok: false, code: 'method_not_allowed', correlationId: correlation.correlationId});
    }
    try {
      await authenticate(req);
    } catch (_) {
      audit(logger, 'INFO', {...correlation, outcome: 'unauthenticated'});
      return res.status(401).json({ok: false, code: 'unauthenticated', correlationId: correlation.correlationId});
    }
    try {
      const result = await runIsolationProof();
      if (!result || !['proven', 'not_proven'].includes(result.verdict)) {
        throw new Error('invalid isolation proof result');
      }
      const ok = result.verdict === 'proven';
      audit(logger, ok ? 'INFO' : 'ERROR', {...correlation, outcome: result.verdict,
        namedOutcome: result.namedDatabase?.outcome, defaultOutcome: result.defaultDatabase?.outcome});
      return res.status(ok ? 200 : 409).json({
        ok,
        code: ok ? 'isolation_proven' : 'isolation_not_proven',
        correlationId: correlation.correlationId,
        result,
      });
    } catch (_) {
      audit(logger, 'ERROR', {...correlation, outcome: 'handler_failure'});
      return res.status(503).json({
        ok: false,
        code: 'diagnostic_unavailable',
        correlationId: correlation.correlationId,
      });
    }
  };
}

module.exports = {correlationFor, createDiagnosticHandler};
