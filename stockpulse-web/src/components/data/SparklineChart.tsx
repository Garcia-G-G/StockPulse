"use client";
import { useRef, useEffect } from "react";

interface SparklineChartProps {
  data: number[];
  width?: number;
  height?: number;
  color?: string;
}

export function SparklineChart({ data, width = 120, height = 32, color }: SparklineChartProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || data.length < 2) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const dpr = window.devicePixelRatio || 1;
    canvas.width = width * dpr;
    canvas.height = height * dpr;
    ctx.scale(dpr, dpr);

    const min = Math.min(...data);
    const max = Math.max(...data);
    const range = max - min || 1;

    const isUp = data[data.length - 1] >= data[0];
    const lineColor = color || (isUp ? "#22C55E" : "#EF4444");

    ctx.clearRect(0, 0, width, height);
    ctx.beginPath();
    ctx.strokeStyle = lineColor;
    ctx.lineWidth = 1.5;
    ctx.lineJoin = "round";

    data.forEach((val, i) => {
      const x = (i / (data.length - 1)) * width;
      const y = height - ((val - min) / range) * (height - 4) - 2;
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    });
    ctx.stroke();

    // Gradient fill
    ctx.lineTo(width, height);
    ctx.lineTo(0, height);
    ctx.closePath();
    const gradient = ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, isUp ? "rgba(34,197,94,0.1)" : "rgba(239,68,68,0.1)");
    gradient.addColorStop(1, "transparent");
    ctx.fillStyle = gradient;
    ctx.fill();
  }, [data, width, height, color]);

  return <canvas ref={canvasRef} style={{ width, height }} className="block" />;
}
