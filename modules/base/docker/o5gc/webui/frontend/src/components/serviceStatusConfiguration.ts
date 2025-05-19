import { symOutlinedSkull } from '@quasar/extras/material-symbols-outlined'

export const healthExecutionStatusToBarColorMap = {
    'created': {
      'barColor': 'grey-9',
      'iconName': 'construction',
      'tooltip': 'Created'
    },
    'running': {
      'barColor': 'positive',
      'iconName': 'play_circle',
      'tooltip': 'Running'
    },
    'starting': {
      'barColor': 'positive',
      'iconName': 'rocket_launch',
      'tooltip': 'Starting'
    },
    'healthy': {
      'barColor': 'positive',
      'iconName': 'play_circle',
      'tooltip': 'Healthy'
    },
    'unhealthy': {
      'barColor': 'orange-10',
      'iconName': 'warning',
      'tooltip': 'Unhealthy'
    },
    'restarting': {
      'barColor': 'orange-10',
      'iconName': 'restart_alt',
      'tooltip': 'Restarting'
    },
    'removing': {
      'barColor': 'grey-9',
      'iconName': 'auto_delete',
      'tooltip': 'Removing'
    },
    'paused': {
      'barColor': 'grey-9',
      'iconName': 'pause_circle',
      'tooltip': 'Paused'
    },
    'exited': {
      'barColor': 'grey-9',
      'iconName': 'stop_circle',
      'tooltip': 'Exited with unknown status'
    },
    'exited-successful': {
      'barColor': 'grey-9',
      'iconName': 'stop_circle',
      'tooltip': 'Exited successfully'
    },
    'exited-error': {
      'barColor': 'negative',
      'iconName': 'cancel',
      'tooltip': 'Exited with error'
    },
    'dead': {
      'barColor': 'grey-9',
      'iconName': symOutlinedSkull,
      'tooltip': 'Dead'
    }
  };
