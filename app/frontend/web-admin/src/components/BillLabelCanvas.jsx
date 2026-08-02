import { useCallback, useEffect, useRef, useState } from "react";

const ENTITY_COLORS = {
  SELLER: "#2563eb",
  ADDRESS: "#9333ea",
  TIMESTAMP: "#ea580c",
  TOTAL_COST: "#16a34a",
  OTHER: "#94a3b8",
};

const HANDLE = 8;

function boxCoords(b) {
  const x1 = b.x1 ?? b.bbox?.[0] ?? 0;
  const y1 = b.y1 ?? b.bbox?.[1] ?? 0;
  const x2 = b.x2 ?? b.bbox?.[2] ?? x1 + 1;
  const y2 = b.y2 ?? b.bbox?.[3] ?? y1 + 1;
  return { x1, y1, x2, y2 };
}

function patchBox(b, coords) {
  const next = { ...b, ...coords };
  if (b.bbox) {
    next.bbox = [coords.x1, coords.y1, coords.x2, coords.y2];
  }
  return next;
}

export default function BillLabelCanvas({
  imageUrl,
  boxes,
  selectedIdx,
  onSelectBox,
  onBoxesChange,
  readOnly = false,
  drawMode = false,
  onDrawComplete,
}) {
  const wrapRef = useRef(null);
  const canvasRef = useRef(null);
  const imgRef = useRef(null);
  const [scale, setScale] = useState({ sx: 1, sy: 1, w: 0, h: 0 });
  const [zoom, setZoom] = useState(1);
  const dragRef = useRef(null);
  const [draftBox, setDraftBox] = useState(null);
  const editable = !readOnly && Boolean(onBoxesChange);

  // Reset zoom khi đổi ảnh
  useEffect(() => {
    setZoom(1);
  }, [imageUrl]);

  const recalcScale = useCallback(() => {
    const img = imgRef.current;
    const wrap = wrapRef.current;
    if (!img || !wrap || !img.naturalWidth) return;

    const maxW = wrap.clientWidth || 600;
    const maxH = wrap.clientHeight || 520;
    const imgW = img.naturalWidth;
    const imgH = img.naturalHeight;
    const ratio = imgH / imgW;

    // Fit by width first
    let w = Math.min(maxW, imgW);
    let h = w * ratio;

    // If it's still too tall, fit by height
    if (h > maxH) {
      h = Math.min(maxH, imgH);
      w = h / ratio;
    }

    setScale({
      w,
      h,
      sx: w / imgW,
      sy: h / imgH,
    });
  }, []);

  useEffect(() => {
    recalcScale();
    window.addEventListener("resize", recalcScale);
    return () => window.removeEventListener("resize", recalcScale);
  }, [recalcScale, imageUrl]);

  // Hỗ trợ Ctrl + cuộn chuột để phóng to/thu nhỏ
  useEffect(() => {
    const wrap = wrapRef.current;
    if (!wrap) return;
    const onWheel = (e) => {
      if (e.ctrlKey || e.metaKey) {
        e.preventDefault();
        const delta = e.deltaY < 0 ? 0.15 : -0.15;
        setZoom((prev) => Math.min(Math.max(0.5, Number((prev + delta).toFixed(2))), 4.0));
      }
    };
    wrap.addEventListener("wheel", onWheel, { passive: false });
    return () => wrap.removeEventListener("wheel", onWheel);
  }, []);

  const toImage = useCallback(
    (cx, cy) => {
      const sx = scale.sx * zoom;
      const sy = scale.sy * zoom;
      return {
        x: sx > 0 ? cx / sx : 0,
        y: sy > 0 ? cy / sy : 0,
      };
    },
    [scale.sx, scale.sy, zoom],
  );

  const applyDrag = useCallback(
    (clientX, clientY) => {
      const drag = dragRef.current;
      if (!drag) return;
      if (drag.mode !== "draw-new" && selectedIdx == null) return;
      const canvasEl = canvasRef.current;
      if (!canvasEl) return;
      const rect = canvasEl.getBoundingClientRect();
      const cx = clientX - rect.left;
      const cy = clientY - rect.top;
      const pt = toImage(cx, cy);
      const { mode, startPt, startBox } = drag;
      const minSize = 4;

      if (mode === "draw-new") {
        const x1n = Math.min(startPt.x, pt.x);
        const y1n = Math.min(startPt.y, pt.y);
        const x2n = Math.max(startPt.x, pt.x);
        const y2n = Math.max(startPt.y, pt.y);
        drag.draftCoords = { x1: x1n, y1: y1n, x2: x2n, y2: y2n };
        setDraftBox(drag.draftCoords);
        return;
      }

      let { x1, y1, x2, y2 } = startBox;
      const dx = pt.x - startPt.x;
      const dy = pt.y - startPt.y;

      if (mode === "move") {
        x1 += dx;
        y1 += dy;
        x2 += dx;
        y2 += dy;
      } else if (mode === "resize-se") {
        x2 = Math.max(x1 + minSize, startBox.x2 + dx);
        y2 = Math.max(y1 + minSize, startBox.y2 + dy);
      } else if (mode === "resize-nw") {
        x1 = Math.min(startBox.x2 - minSize, startBox.x1 + dx);
        y1 = Math.min(startBox.y2 - minSize, startBox.y1 + dy);
      }

      const next = boxes.map((b, i) =>
        i === selectedIdx ? patchBox(b, { x1, y1, x2, y2 }) : b,
      );
      onBoxesChange?.(next);
    },
    [boxes, onBoxesChange, selectedIdx, toImage],
  );

  const commitDraw = useCallback(() => {
    const drag = dragRef.current;
    if (drag?.mode !== "draw-new" || !drag.draftCoords || !onBoxesChange) return;
    const { x1, y1, x2, y2 } = drag.draftCoords;
    const minSize = 4;
    if (x2 - x1 >= minSize && y2 - y1 >= minSize) {
      const newBox = { text: "", entity: "OTHER", x1, y1, x2, y2 };
      const next = [...boxes, newBox];
      onBoxesChange(next);
      onSelectBox?.(next.length - 1);
      onDrawComplete?.();
    }
    dragRef.current = null;
    setDraftBox(null);
  }, [boxes, onBoxesChange, onDrawComplete, onSelectBox]);

  useEffect(() => {
    const onMove = (e) => applyDrag(e.clientX, e.clientY);
    const onUp = () => {
      if (dragRef.current?.mode === "draw-new") {
        commitDraw();
        return;
      }
      dragRef.current = null;
    };
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
    return () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseup", onUp);
    };
  }, [applyDrag, commitDraw]);

  useEffect(() => {
    if (!drawMode) {
      dragRef.current = null;
      setDraftBox(null);
    }
  }, [drawMode]);

  const startDrag = (e, idx, mode) => {
    if (!editable || drawMode) return;
    e.stopPropagation();
    onSelectBox?.(idx);
    const b = boxes[idx];
    const coords = boxCoords(b);
    const canvasEl = canvasRef.current;
    if (!canvasEl) return;
    const rect = canvasEl.getBoundingClientRect();
    const pt = toImage(e.clientX - rect.left, e.clientY - rect.top);
    dragRef.current = { mode, startPt: pt, startBox: coords };
  };

  const startDraw = (e) => {
    if (!editable || !drawMode) return;
    e.preventDefault();
    e.stopPropagation();
    onSelectBox?.(null);
    const canvasEl = canvasRef.current;
    if (!canvasEl) return;
    const rect = canvasEl.getBoundingClientRect();
    const pt = toImage(e.clientX - rect.left, e.clientY - rect.top);
    dragRef.current = { mode: "draw-new", startPt: pt, draftCoords: { x1: pt.x, y1: pt.y, x2: pt.x, y2: pt.y } };
    setDraftBox({ x1: pt.x, y1: pt.y, x2: pt.x, y2: pt.y });
  };

  if (!imageUrl) {
    return <p className="muted">Không có ảnh — upload lại sample.</p>;
  }

  const curW = (scale.w || 0) * zoom;
  const curH = (scale.h || 0) * zoom;
  const curSx = scale.sx * zoom;
  const curSy = scale.sy * zoom;

  const zoomIn = () => setZoom((prev) => Math.min(4.0, Number((prev + 0.25).toFixed(2))));
  const zoomOut = () => setZoom((prev) => Math.max(0.5, Number((prev - 0.25).toFixed(2))));
  const resetZoom = () => setZoom(1);

  return (
    <div className="bill-canvas-container">
      {/* Zoom Toolbar */}
      <div className="bill-canvas-zoom-bar">
        <button
          type="button"
          className="bill-zoom-btn"
          onClick={zoomOut}
          title="Thu nhỏ (-)"
          disabled={zoom <= 0.5}
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <line x1="5" y1="12" x2="19" y2="12" />
          </svg>
        </button>
        <button
          type="button"
          className="bill-zoom-level"
          onClick={resetZoom}
          title="Bấm để đặt lại kích thước gốc (100%)"
        >
          {Math.round(zoom * 100)}%
        </button>
        <button
          type="button"
          className="bill-zoom-btn"
          onClick={zoomIn}
          title="Phóng to (+)"
          disabled={zoom >= 4.0}
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <line x1="12" y1="5" x2="12" y2="19" />
            <line x1="5" y1="12" x2="19" y2="12" />
          </svg>
        </button>
        <div className="bill-zoom-divider" />
        <button
          type="button"
          className={`bill-zoom-action ${zoom === 1 ? "active" : ""}`}
          onClick={resetZoom}
          title="Vừa khung nhìn chuẩn"
        >
          Vừa khung
        </button>
        <button
          type="button"
          className={`bill-zoom-action ${zoom === 1.5 ? "active" : ""}`}
          onClick={() => setZoom(1.5)}
          title="Phóng to 1.5 lần"
        >
          1.5x
        </button>
        <button
          type="button"
          className={`bill-zoom-action ${zoom === 2.0 ? "active" : ""}`}
          onClick={() => setZoom(2.0)}
          title="Phóng to 2.0 lần"
        >
          2.0x
        </button>
      </div>

      <div className={`bill-label-canvas-wrap ${drawMode ? "draw-mode" : ""}`} ref={wrapRef}>
        <div className="bill-canvas-inner-scroll">
          <div
            className="bill-label-canvas"
            ref={canvasRef}
            style={{ width: curW || "100%", height: curH || "auto" }}
          >
            <img
              ref={imgRef}
              src={imageUrl}
              alt="Receipt"
              onLoad={recalcScale}
              draggable={false}
              style={{
                width: curW || "100%",
                height: curH || "auto",
                display: "block",
                userSelect: "none",
              }}
            />
            <svg
              className="bill-label-overlay"
              width={curW}
              height={curH}
              viewBox={`0 0 ${curW} ${curH}`}
            >
              {editable && drawMode && (
                <rect
                  className="bill-draw-surface"
                  x={0}
                  y={0}
                  width={curW}
                  height={curH}
                  fill="transparent"
                  onMouseDown={startDraw}
                />
              )}
              {boxes.map((b, idx) => {
                const { x1, y1, x2, y2 } = boxCoords(b);
                const ent = b.entity || "OTHER";
                const color = ENTITY_COLORS[ent] || ENTITY_COLORS.OTHER;
                const active = idx === selectedIdx;
                const sx1 = x1 * curSx;
                const sy1 = y1 * curSy;
                const sw = Math.max((x2 - x1) * curSx, 2);
                const sh = Math.max((y2 - y1) * curSy, 2);
                return (
                  <g key={idx} style={{ pointerEvents: drawMode ? "none" : "auto" }}>
                    <rect
                      x={sx1}
                      y={sy1}
                      width={sw}
                      height={sh}
                      fill={active ? `${color}55` : `${color}22`}
                      stroke={color}
                      strokeWidth={active ? 2.5 : 1.5}
                      onMouseDown={(e) => {
                        if (!editable) {
                          e.stopPropagation();
                          onSelectBox?.(idx);
                          return;
                        }
                        startDrag(e, idx, "move");
                      }}
                      style={{ cursor: editable ? "move" : "pointer" }}
                    />
                    <text
                      x={sx1 + 2}
                      y={Math.max(sy1 - 4, 10)}
                      fill={color}
                      fontSize={Math.max(10, Math.min(13, 10 * Math.sqrt(zoom)))}
                      fontWeight={active ? 700 : 500}
                      pointerEvents="none"
                    >
                      {ent}
                    </text>
                    {active && editable && !drawMode && (
                      <>
                        <rect
                          x={sx1 - HANDLE / 2}
                          y={sy1 - HANDLE / 2}
                          width={HANDLE}
                          height={HANDLE}
                          fill="#fff"
                          stroke={color}
                          strokeWidth={1.5}
                          onMouseDown={(e) => startDrag(e, idx, "resize-nw")}
                          style={{ cursor: "nwse-resize" }}
                        />
                        <rect
                          x={sx1 + sw - HANDLE / 2}
                          y={sy1 + sh - HANDLE / 2}
                          width={HANDLE}
                          height={HANDLE}
                          fill="#fff"
                          stroke={color}
                          strokeWidth={1.5}
                          onMouseDown={(e) => startDrag(e, idx, "resize-se")}
                          style={{ cursor: "nwse-resize" }}
                        />
                      </>
                    )}
                  </g>
                );
              })}
              {draftBox && (
                <rect
                  x={draftBox.x1 * curSx}
                  y={draftBox.y1 * curSy}
                  width={Math.max((draftBox.x2 - draftBox.x1) * curSx, 2)}
                  height={Math.max((draftBox.y2 - draftBox.y1) * curSy, 2)}
                  fill="rgba(234, 179, 8, 0.15)"
                  stroke="#eab308"
                  strokeWidth={2}
                  strokeDasharray="6 4"
                  pointerEvents="none"
                />
              )}
            </svg>
          </div>
        </div>
      </div>
      <p className="muted canvas-hint" style={{ marginTop: 8, textAlign: "center" }}>
        {readOnly
          ? "Chỉ xem nhãn auto — bấm Gán nhãn auto để cập nhật từ model. Dùng Ctrl + cuộn chuột hoặc thanh công cụ để phóng to ảnh."
          : drawMode
            ? "Kéo trên ảnh để vẽ bbox mới (OTHER) · bấm Hủy vẽ để thoát. Dùng Ctrl + cuộn chuột để zoom."
            : "Kéo box để di chuyển · góc trắng để resize · Giữ Ctrl + cuộn chuột để phóng to/thu nhỏ ảnh."}
      </p>
    </div>
  );
}
