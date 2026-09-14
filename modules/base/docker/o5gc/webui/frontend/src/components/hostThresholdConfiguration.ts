/*
 * Thresholds for the host metrics strip. All values are percent:
 *   load   = load1 / cores * 100   (can exceed 100)
 *   cpu    = 100 - idle share over the last sampling window
 *   memory = (total - available) / total * 100
 */
export const hostThresholds = {
  'load': { 'warn': 80, 'crit': 150 },
  'cpu': { 'warn': 75, 'crit': 90 },
  'memory': { 'warn': 85, 'crit': 95 }
};

/*
 * Colour and icon per threshold level. Every colour change carries an icon change,
 * so the level is never signalled by colour alone.
 */
export const hostThresholdLevelToStyleMap = {
  'unknown': {
    'textColor': 'grey-5',
    'iconName': null,
    'tooltip': 'No data'
  },
  'ok': {
    'textColor': 'white',
    'iconName': null,
    'tooltip': 'Normal'
  },
  'warn': {
    'textColor': 'orange-10',
    'iconName': 'warning',
    'tooltip': 'Elevated'
  },
  'crit': {
    'textColor': 'negative',
    'iconName': 'error',
    'tooltip': 'Critical'
  }
};

export function hostThresholdLevel(metric: 'load'|'cpu'|'memory', percentage: number|null): 'unknown'|'ok'|'warn'|'crit' {
  if(percentage === null || !isFinite(percentage)) return 'unknown';
  if(percentage >= hostThresholds[metric].crit) return 'crit';
  if(percentage >= hostThresholds[metric].warn) return 'warn';
  return 'ok';
}
