// Logger đơn giản: in ra console kèm thời gian.
const isTest = process.env.NODE_ENV === 'test';

function stamp() {
  return new Date().toISOString();
}

export const logger = {
  info: (...args) => !isTest && console.log(`[${stamp()}] INFO `, ...args),
  warn: (...args) => !isTest && console.warn(`[${stamp()}] WARN `, ...args),
  error: (...args) => console.error(`[${stamp()}] ERROR`, ...args),
};
