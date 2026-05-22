/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './index.html',
    './src/**/*.{svelte,js,ts}'
  ],
  theme: {
    extend: {
      colors: {
        primary: '#0071E3',
        background: '#FBFBFD',
        surface: '#FFFFFF',
        text: {
          primary: '#1D1D1F',
          secondary: '#6E6E73'
        }
      },
      fontFamily: {
        sans: ['-apple-system', 'BlinkMacSystemFont', 'SF Pro Text', 'Helvetica Neue', 'sans-serif'],
        display: ['-apple-system', 'BlinkMacSystemFont', 'SF Pro Display', 'Helvetica Neue', 'sans-serif']
      }
    }
  },
  plugins: []
}
