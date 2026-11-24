import { boxCorners, project, type Camera } from '../src/components/display/caseCamera';

/** What case-budget.spec.ts reads off the page of the scene: the camera, the wall's published boxes and the drawn cabinets' spans. */
export interface WallScene {
  camera: { x: number; y: number; z: number; pitch: number; focalPx: number; width: number; height: number };
  pan: number;
  /** [x0, x1, y1, z0, z1] per cabinet of the wall. */
  wall: number[][];
  spans: { x0: number; x1: number }[];
}

/**
 * Ruling 33: the widest stretch (px) of the frame where the wall stands, from where its camera and pan put the wall's
 * two ends (the published boxes, any wall), that no drawn cabinet covers as the browser draws it; and the narrowest
 * drawn cabinet. No cabinet drawn leaves the whole stretch bare, with no cabinet to be narrower than (0 px, so the
 * check against half of it fails); a span that is not finite (a cabinet with no face, or one past a wall end) is no cabinet.
 */
export function wallCover(scene: WallScene): { blank: number; narrowest: number } {
  const c = scene.camera;
  const camera: Camera = { x: c.x, y: c.y, z: c.z, pitch: c.pitch, focalPx: c.focalPx, frame: { width: c.width, height: c.height } };
  const xs = (b: number[]) => boxCorners(b[0], b[1], 0, b[2], b[3], b[4]).map((p) => project(camera, p).x + scene.pan);
  const lo = Math.max(0, Math.min(...xs(scene.wall[0])));
  const hi = Math.min(camera.frame.width, Math.max(...xs(scene.wall[scene.wall.length - 1])));
  const drawn = scene.spans.filter((s) => Number.isFinite(s.x0) && Number.isFinite(s.x1));
  if (drawn.length === 0) return { blank: hi - lo, narrowest: 0 };
  const spans = drawn.map((s) => [Math.max(lo, s.x0), Math.min(hi, s.x1)] as const).filter(([a, b]) => b > a);
  spans.sort((a, b) => a[0] - b[0]);
  let reach = lo;
  let blank = 0;
  for (const [a, b] of spans) {
    blank = Math.max(blank, a - reach);
    reach = Math.max(reach, b);
  }
  return { blank: Math.max(blank, hi - reach), narrowest: Math.min(...drawn.map((s) => s.x1 - s.x0)) };
}
