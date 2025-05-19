import { Notify } from 'quasar';

export function generateErrorNotification(message: string, color='negative', icon='announcement') {
    Notify.create({message, color, icon});
}
