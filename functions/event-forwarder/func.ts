import { initLogger, info, error } from '../shared/lib/logger';

/**
 * Event Forwarder - Deployed in TARGET TENANCY only.
 * Receives OCI Events (instance launch, image creation) and forwards
 * them via HTTPS POST to the scanning tenancy's API Gateway.
 */

interface OciEvent {
  eventType: string;
  cloudEventsVersion: string;
  eventTypeVersion: string;
  source: string;
  eventId: string;
  eventTime: string;
  contentType: string;
  data: {
    compartmentId: string;
    compartmentName: string;
    resourceName: string;
    resourceId: string;
    availabilityDomain: string;
    freeformTags: Record<string, string>;
    definedTags: Record<string, Record<string, string>>;
    additionalDetails?: Record<string, unknown>;
  };
}

async function handleRequest(event: OciEvent): Promise<unknown> {
  const endpoint = process.env.SCANNING_API_ENDPOINT || '';
  const apiKey = process.env.API_KEY || '';

  if (!endpoint) {
    throw new Error('SCANNING_API_ENDPOINT not configured');
  }

  info('Forwarding event', {
    eventType: event.eventType,
    resourceId: event.data?.resourceId,
    region: event.source,
  });

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
    },
    body: JSON.stringify({
      source: 'event-forwarder',
      tenancyId: event.data?.compartmentId?.split('.')[3] || '',
      event,
      forwardedAt: new Date().toISOString(),
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    error('Event forwarding failed', {
      statusCode: response.status,
      body,
    });
    throw new Error(`Event forwarding failed: ${response.status}`);
  }

  info('Event forwarded successfully', {
    statusCode: response.status,
    eventId: event.eventId,
  });

  return { success: true, eventId: event.eventId };
}

async function main(): Promise<void> {
  let inputData = '';
  for await (const chunk of process.stdin) {
    inputData += chunk;
  }

  const event: OciEvent = JSON.parse(inputData || '{}');
  initLogger('event-forwarder', process.env.FN_CALL_ID || '');

  try {
    const result = await handleRequest(event);
    process.stdout.write(JSON.stringify(result));
  } catch (e: unknown) {
    const err = e as Error;
    error('event-forwarder failed', { error: err.message });
    process.stdout.write(JSON.stringify({ error: err.message }));
  }
}

main().catch((e) => {
  process.stderr.write(JSON.stringify({ error: e.message }));
  process.exit(1);
});
