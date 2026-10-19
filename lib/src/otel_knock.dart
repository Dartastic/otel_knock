// Licensed under the MIT License.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_knock_suppression.dart';

const _tracerName = 'dartastic_otel_libs_knock';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class KnockResult {
  /// Creates a result.
  const KnockResult({
    this.workflowKey,
    this.tenantId,
    this.recipientCount,
    this.channelTypes,
    this.environment,
    this.batchKey,
    this.cancellationKey,
    this.scheduled,
    this.requestId,
    this.statusCode,
  });

  /// `workflow_key` of the workflow that was triggered.
  final String? workflowKey;

  /// `tenant` id — multi-tenant routing dim.
  final String? tenantId;

  /// Recipients in the trigger call.
  final int? recipientCount;

  /// Comma-joined channel types that fired (`email`, `sms`, `push`,
  /// `chat`, `in_app_feed`, `http`).
  final String? channelTypes;

  /// `development` / `production` — Knock environments are billed
  /// independently for some plans.
  final String? environment;

  /// `batch_key` when delivery was batched.
  final String? batchKey;

  /// `cancellation_key` returned for schedulable workflows.
  final String? cancellationKey;

  /// True if the workflow was scheduled vs immediate.
  final bool? scheduled;

  /// `X-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class KnockCallResult<T> {
  /// Creates a call result.
  const KnockCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final KnockResult? result;
}

/// Wraps a Knock API call in a CLIENT span. [operation] is one of
/// `workflows.trigger`, `workflows.cancel`, `workflows.list`,
/// `workflows.run.list`, `users.identify`, `users.bulk_identify`,
/// `users.delete`, `users.preferences.set`, `users.preferences.get`,
/// `users.messages.list`, `users.feed.get`, `schedules.create`,
/// `schedules.list`, `schedules.delete`, `tenants.set`,
/// `objects.set`, `channels.list`, `bulk.identify`.
Future<T> tracedKnock<T>({
  required String operation,
  required Future<KnockCallResult<T>> Function() invoke,
  String? environment,
}) async {
  if (knockInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'knock',
    'rpc.method': operation,
    'knock.operation': operation,
  };
  if (environment != null) m['knock.environment'] = environment;

  final span = _tracer().startSpan(
    'knock $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.workflowKey != null) {
        extras.add(OTelAPI.attributeString(
          'knock.workflow.key',
          r.result!.workflowKey!,
        ));
      }
      if (r.result!.tenantId != null) {
        extras.add(OTelAPI.attributeString(
          'knock.tenant.id',
          r.result!.tenantId!,
        ));
      }
      if (r.result!.recipientCount != null) {
        extras.add(OTelAPI.attributeInt(
          'knock.recipient_count',
          r.result!.recipientCount!,
        ));
      }
      if (r.result!.channelTypes != null) {
        extras.add(OTelAPI.attributeString(
          'knock.channel.types',
          r.result!.channelTypes!,
        ));
      }
      if (r.result!.environment != null) {
        extras.add(OTelAPI.attributeString(
          'knock.environment',
          r.result!.environment!,
        ));
      }
      if (r.result!.batchKey != null) {
        extras.add(OTelAPI.attributeString(
          'knock.batch.key',
          r.result!.batchKey!,
        ));
      }
      if (r.result!.cancellationKey != null) {
        extras.add(OTelAPI.attributeString(
          'knock.cancellation.key',
          r.result!.cancellationKey!,
        ));
      }
      if (r.result!.scheduled != null) {
        extras.add(OTelAPI.attributeBool(
          'knock.scheduled',
          r.result!.scheduled!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'knock.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Knock HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
