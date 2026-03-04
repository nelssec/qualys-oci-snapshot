import { getQueueClient } from './oci-client';
import { info, error } from './logger';
import type { QueueMessage } from './types';

export async function sendMessage(
  queueId: string,
  content: unknown,
  visibilityInSeconds?: number,
): Promise<string> {
  const client = getQueueClient();
  try {
    const response = await client.putMessages({
      queueId,
      putMessagesDetails: {
        messages: [
          {
            content: JSON.stringify(content),
          },
        ],
      },
    });
    const messageId = response.putMessages?.entries?.[0]?.id || '';
    info('Queue sendMessage success', { queueId, messageId });
    return messageId;
  } catch (e: unknown) {
    const err = e as Error;
    error('Queue sendMessage failed', { queueId, error: err.message });
    throw e;
  }
}

export async function sendMessageBatch(
  queueId: string,
  messages: unknown[],
): Promise<string[]> {
  const client = getQueueClient();
  // OCI Queue batch limit is 20 messages
  const batchSize = 20;
  const allIds: string[] = [];

  for (let i = 0; i < messages.length; i += batchSize) {
    const batch = messages.slice(i, i + batchSize);
    try {
      const response = await client.putMessages({
        queueId,
        putMessagesDetails: {
          messages: batch.map((msg) => ({
            content: JSON.stringify(msg),
          })),
        },
      });
      const ids = response.putMessages?.entries?.map((e) => e.id || '') || [];
      allIds.push(...ids);
    } catch (e: unknown) {
      const err = e as Error;
      error('Queue sendMessageBatch failed', { queueId, error: err.message });
      throw e;
    }
  }

  info('Queue sendMessageBatch success', { queueId, count: allIds.length });
  return allIds;
}

export async function receiveMessages(
  queueId: string,
  maxMessages: number = 10,
  visibilityInSeconds: number = 30,
  waitTimeSeconds: number = 20,
): Promise<QueueMessage[]> {
  const client = getQueueClient();
  try {
    const response = await client.getMessages({
      queueId,
      limit: maxMessages,
      visibilityInSeconds,
      timeoutInSeconds: waitTimeSeconds,
    });

    const messages: QueueMessage[] =
      response.getMessages?.messages?.map((m) => ({
        id: m.id || '',
        content: m.content || '',
        receipt: m.receipt || '',
        deliveryCount: m.deliveryCount || 0,
        expireAfter: m.expireAfter?.toISOString() || '',
        visibleAfter: m.visibleAfter?.toISOString() || '',
      })) || [];

    info('Queue receiveMessages success', { queueId, count: messages.length });
    return messages;
  } catch (e: unknown) {
    const err = e as Error;
    error('Queue receiveMessages failed', { queueId, error: err.message });
    throw e;
  }
}

export async function deleteMessage(queueId: string, receipt: string): Promise<void> {
  const client = getQueueClient();
  try {
    await client.deleteMessage({
      queueId,
      messageReceipt: receipt,
    });
    info('Queue deleteMessage success', { queueId });
  } catch (e: unknown) {
    const err = e as Error;
    error('Queue deleteMessage failed', { queueId, error: err.message });
    throw e;
  }
}

export async function updateMessageVisibility(
  queueId: string,
  receipt: string,
  visibilityInSeconds: number,
): Promise<string> {
  const client = getQueueClient();
  try {
    const response = await client.updateMessage({
      queueId,
      messageReceipt: receipt,
      updateMessageDetails: {
        visibilityInSeconds,
      },
    });
    info('Queue updateMessageVisibility success', { queueId });
    return response.updateMessageResult?.receipt || '';
  } catch (e: unknown) {
    const err = e as Error;
    error('Queue updateMessageVisibility failed', { queueId, error: err.message });
    throw e;
  }
}
