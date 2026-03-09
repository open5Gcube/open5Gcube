import { boot } from 'quasar/wrappers'
import axios from 'axios'
import axiosRetry from 'axios-retry';

const api = axios.create({ baseURL: process.env.API_URL })
// Configure Axios to automatically retry on Network Errors (like Firefox's network-changed abort)
axiosRetry(api, {
  retries: 3,
  retryCondition: (error) => {
    return error.code === 'ERR_NETWORK' || axiosRetry.isNetworkOrIdempotentRequestError(error);
  },
  retryDelay: (retryCount) => {
    return retryCount * 1000; // Wait 1s, then 2s, etc.
  }
});

export default boot(({ app }) => {
  // for use inside Vue files (Options API) through this.$axios and this.$api

  app.config.globalProperties.$axios = axios
  // ^ ^ ^ this will allow you to use this.$axios (for Vue Options API form)
  //       so you won't necessarily have to import axios in each vue file

  app.config.globalProperties.$api = api
  // ^ ^ ^ this will allow you to use this.$api (for Vue Options API form)
  //       so you can easily perform requests against your app's API
})

export { axios, api }
