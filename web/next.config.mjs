/** @type {import('next').NextConfig} */
const nextConfig = {
  // Pages sirve el sitio bajo /dotfiles (project page, no user page).
  // Sin basePath, todos los assets dan 404 en producción y ninguno en local.
  output: 'export',
  basePath: '/dotfiles',
  images: { unoptimized: true },
  trailingSlash: true,
}

export default nextConfig
