import { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    redirect: '/serviceOverview'
  },

  {
    path: '/stack/:stackName',
    component: () => import('layouts/MainLayout.vue'),
    children: [{ path: '', component: () => import('pages/StackOverview.vue')}]
  },

  {
    path: '/serviceOverview',
    component: () => import('layouts/MainLayout.vue'),
    children: [{ path: '', component: () => import('pages/ServiceOverview.vue')}]
  },

  {
    path: '/service/:serviceId',
    component: () => import('layouts/MainLayout.vue'),
    children: [{ path: '', component: () => import('pages/ServiceDetail.vue')}]
  },

  {
    path: '/simWriter',
    component: () => import('layouts/MainLayout.vue'),
    children: [{ path: '', component: () => import('pages/SimWriter.vue')}]
  },

  // Always leave this as last one,
  // but you can also remove it
  {
    path: '/:catchAll(.*)*',
    component: () => import('pages/ErrorNotFound.vue'),
  },
];

export default routes;
