# El front-end corre en otro origen (Vite usa el puerto 5173 en desarrollo) y
# consume /api/*. Los orígenes permitidos se configuran con CORS_ORIGINS,
# separados por coma. La API usa token en el header Authorization, no cookies.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("CORS_ORIGINS", "http://localhost:5173,http://127.0.0.1:5173").split(",").map(&:strip))

    resource "/api/*",
             headers: :any,
             methods: %i[get post put patch delete options head],
             max_age: 600
  end
end
