import { API_BASE_URL, session } from "./api.js";

const KEY = "educa-pos-print-relay-session";
const id = () => localStorage.getItem(KEY) || (localStorage.setItem(KEY, crypto.randomUUID()), localStorage.getItem(KEY));

export function createPrintRelay({ device, storeId, printerStatus, onTargets, onRequest, onResult }) {
  let socket, ref = 1, joinRef = null, presence = {}, stopped = false;
  const callbacks = new Map(), topic = `print-relay:${storeId}`;
  const targets = () => Object.entries(presence).flatMap(([session_id, value]) => (value.metas || []).filter((m) => m.device === "desktop" && m.printer_online).map((m) => ({ session_id, ...m })));
  const notify = () => onTargets(targets());
  const send = (event, payload, cb) => {
    const messageRef = String(ref++);
    if (event === "phx_join") joinRef = messageRef;
    if (cb) callbacks.set(messageRef, cb);
    socket?.send(JSON.stringify([joinRef || messageRef, messageRef, topic, event, payload]));
  };
  const connect = async () => {
    if (stopped || !session()?.token) return;
    const url = new URL(API_BASE_URL); url.protocol = url.protocol === "https:" ? "wss:" : "ws:"; url.pathname = "/socket/websocket"; url.search = `vsn=2.0.0&token=${encodeURIComponent(session().token)}`;
    socket = new WebSocket(url);
    socket.onopen = async () => { const status = device === "desktop" ? await printerStatus().catch(() => ({ connected: false })) : {}; send("phx_join", { device, session_id: id(), printer_online: !!status.connected, printer: status.model, label: device === "desktop" ? "Desktop Tauri" : "Mobile POS" }); };
    socket.onmessage = ({ data }) => { const [, messageRef, , event, payload] = JSON.parse(data); if (event === "phx_reply") { const cb = callbacks.get(messageRef); callbacks.delete(messageRef); cb?.(payload); if (payload.response?.targets) onTargets(payload.response.targets); } else if (event === "presence_state") { presence = payload; notify(); } else if (event === "presence_diff") { Object.assign(presence, payload.joins); Object.entries(payload.leaves || {}).forEach(([key, value]) => { const refs = new Set(value.metas.map((m) => m.phx_ref)); const metas = (presence[key]?.metas || []).filter((m) => !refs.has(m.phx_ref)); metas.length ? presence[key] = { metas } : delete presence[key]; }); notify(); } else if (event === "print_request") onRequest?.(payload); else if (event === "print_result") onResult?.(payload); };
    socket.onclose = () => { presence = {}; notify(); if (!stopped) setTimeout(connect, 2_000); };
  };
  return { connect, close: () => { stopped = true; socket?.close(); }, requestPrint: (request_id, target_session_id, receipt) => new Promise((resolve, reject) => send("print", { request_id, target_session_id, receipt }, (reply) => reply.status === "ok" ? resolve(reply.response) : reject(new Error(reply.response?.reason || "Print request failed.")))), reportResult: (payload) => send("print_result", payload), updatePrinter: async () => { if (device !== "desktop" || socket?.readyState !== WebSocket.OPEN) return; const s = await printerStatus().catch(() => ({ connected: false })); send("printer_status", { printer_online: !!s.connected, printer: s.model, label: "Desktop Tauri" }); } };
}
