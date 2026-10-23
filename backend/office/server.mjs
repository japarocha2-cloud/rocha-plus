import { createServer } from 'node:http';
import { createOfficeRuntime } from './runtime.mjs';
const server = createServer(createOfficeRuntime());
server.requestTimeout = 15_000;
server.headersTimeout = 10_000;
server.listen(Number(process.env.PORT ?? 8081), '127.0.0.1');
