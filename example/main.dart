// Licensed under the MIT License.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_knock/otel_knock.dart';

/// Traces Knock calls with OpenTelemetry.
///
/// `otel_knock` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Knock call in
/// [tracedKnock]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'knock-example');

  // Wraps a Knock API call in a CLIENT span.
  final knockId = await tracedKnock<String>(
    operation: 'schedules.create',
    environment: 'example',
    invoke: () async {
      // Make the Knock call here, then report what it returned.
      const id = 'knock_8f3a2c';
      return const KnockCallResult(
          value: id,
          result: KnockResult(
              workflowKey: 'workflow_key',
              tenantId: 'tenant_8f3a2c',
              recipientCount: 3,
              channelTypes: 'email',
              environment: 'development',
              batchKey: 'batch_key',
              cancellationKey: 'cancellation_key',
              scheduled: true,
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedKnock schedules.create returned $knockId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutKnockInstrumentationAsync.
  await runWithoutKnockInstrumentationAsync(
    () => tracedKnock<String>(
      operation: 'schedules.create',
      environment: 'example',
      invoke: () async {
        const id = 'knock_8f3a2c';
        return const KnockCallResult(
            value: id,
            result: KnockResult(
                workflowKey: 'workflow_key',
                tenantId: 'tenant_8f3a2c',
                recipientCount: 3,
                channelTypes: 'email',
                environment: 'development',
                batchKey: 'batch_key',
                cancellationKey: 'cancellation_key',
                scheduled: true,
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
