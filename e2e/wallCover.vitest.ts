import { describe, expect, it } from 'vitest';
import { wallCover, type WallScene } from './wallCover';

// A frame 1000 px wide; the camera 2000 mm from a wall of one 1000 mm cabinet, so the wall stands from x = 206 to 794 px.
const scene = (spans: WallScene['spans']): WallScene => ({
  camera: { x: 500, y: 1000, z: 2000, pitch: 0, focalPx: 1000, width: 1000, height: 800 },
  pan: 0,
  wall: [[0, 1000, 2000, 0, 300]],
  spans,
});
const WALL = 794.1176470588235 - 205.88235294117646;

describe('wallCover: the bare wall inside the frame, and the narrowest drawn cabinet', () => {
  it('a cabinet over the whole wall: nothing bare, the cabinet its own width', () => {
    const { blank, narrowest } = wallCover(scene([{ x0: 100, x1: 900 }]));
    expect(blank).toBe(0);
    expect(narrowest).toBe(800);
  });

  it('a gap between two cabinets, and the bare end past the last: the widest of them', () => {
    const { blank, narrowest } = wallCover(scene([{ x0: 206, x1: 300 }, { x0: 400, x1: 450 }]));
    expect(blank).toBeCloseTo(794.1176 - 450, 3);
    expect(narrowest).toBe(50);
  });

  it('no cabinet drawn at all: the whole wall is bare and the check against half a cabinet fails', () => {
    const { blank, narrowest } = wallCover(scene([]));
    expect(blank).toBeCloseTo(WALL, 3);
    expect(narrowest).toBe(0);
    expect(blank).not.toBeLessThan(narrowest / 2);
  });

  it('a span that is not finite (a cabinet with no face) is no cabinet: it neither hides bare wall nor sets the narrowest', () => {
    const { blank, narrowest } = wallCover(scene([{ x0: 206, x1: 500 }, { x0: Infinity, x1: -Infinity }]));
    expect(blank).toBeCloseTo(794.1176 - 500, 3);
    expect(narrowest).toBe(294);
  });

  it('only spans that are not finite: counted as none drawn', () => {
    const { blank, narrowest } = wallCover(scene([{ x0: Infinity, x1: -Infinity }]));
    expect(blank).toBeCloseTo(WALL, 3);
    expect(narrowest).toBe(0);
  });

  it('a drawn cabinet wholly past the wall\'s end covers none of it: the whole wall is bare, the cabinet still counted for its width', () => {
    const { blank, narrowest } = wallCover(scene([{ x0: 900, x1: 990 }]));
    expect(blank).toBeCloseTo(WALL, 3);
    expect(narrowest).toBe(90);
  });
});
