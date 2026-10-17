// Licensed under the MIT License.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_knock/otel_knock.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_knock-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('workflows.trigger records workflow + tenant + channels', () async {
    await tracedKnock<String>(
      operation: 'workflows.trigger',
      environment: 'production',
      invoke: () async => const KnockCallResult(
        value: 'ok',
        result: KnockResult(
          workflowKey: 'new-comment',
          tenantId: 't-1',
          recipientCount: 3,
          channelTypes: 'email,push,in_app_feed',
          environment: 'production',
          scheduled: false,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('knock workflows.trigger')!);
    expect(a['knock.workflow.key'], 'new-comment');
    expect(a['knock.tenant.id'], 't-1');
    expect(a['knock.recipient_count'], 3);
    expect(a['knock.channel.types'], 'email,push,in_app_feed');
    expect(a['knock.environment'], 'production');
  });

  test('schedules.create records scheduled + cancellation', () async {
    await tracedKnock<String>(
      operation: 'schedules.create',
      invoke: () async => const KnockCallResult(
        value: 'ok',
        result: KnockResult(
          scheduled: true,
          cancellationKey: 'cancel-key-1',
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('knock schedules.create')!);
    expect(a['knock.scheduled'], true);
    expect(a['knock.cancellation.key'], 'cancel-key-1');
  });

  test('suppression skips spans', () async {
    await runWithoutKnockInstrumentationAsync(() async {
      await tracedKnock<String>(
        operation: 'users.identify',
        invoke: () async => const KnockCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('knock '), isEmpty);
  });
}
