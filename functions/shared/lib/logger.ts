export enum LogLevel {
  DEBUG = 'DEBUG',
  INFO = 'INFO',
  WARN = 'WARN',
  ERROR = 'ERROR',
}

interface LogEntry {
  timestamp: string;
  level: LogLevel;
  message: string;
  functionName?: string;
  callId?: string;
  [key: string]: unknown;
}

let currentLevel = LogLevel.INFO;
let functionName = 'unknown';
let callId = '';

export function initLogger(fnName: string, fnCallId: string, level?: LogLevel): void {
  functionName = fnName;
  callId = fnCallId;
  if (level) currentLevel = level;
}

const levelOrder: Record<LogLevel, number> = {
  [LogLevel.DEBUG]: 0,
  [LogLevel.INFO]: 1,
  [LogLevel.WARN]: 2,
  [LogLevel.ERROR]: 3,
};

function shouldLog(level: LogLevel): boolean {
  return levelOrder[level] >= levelOrder[currentLevel];
}

function formatLog(level: LogLevel, message: string, extra?: Record<string, unknown>): string {
  const entry: LogEntry = {
    timestamp: new Date().toISOString(),
    level,
    message,
    functionName,
    callId,
    ...extra,
  };
  return JSON.stringify(entry);
}

export function debug(message: string, extra?: Record<string, unknown>): void {
  if (shouldLog(LogLevel.DEBUG)) {
    process.stderr.write(formatLog(LogLevel.DEBUG, message, extra) + '\n');
  }
}

export function info(message: string, extra?: Record<string, unknown>): void {
  if (shouldLog(LogLevel.INFO)) {
    process.stderr.write(formatLog(LogLevel.INFO, message, extra) + '\n');
  }
}

export function warn(message: string, extra?: Record<string, unknown>): void {
  if (shouldLog(LogLevel.WARN)) {
    process.stderr.write(formatLog(LogLevel.WARN, message, extra) + '\n');
  }
}

export function error(message: string, extra?: Record<string, unknown>): void {
  if (shouldLog(LogLevel.ERROR)) {
    process.stderr.write(formatLog(LogLevel.ERROR, message, extra) + '\n');
  }
}
