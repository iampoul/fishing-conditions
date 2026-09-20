.pragma library

function finiteNumber(value) {
    var number = Number(value)
    return Number.isFinite(number) ? number : null
}

function validCoordinates(latitude, longitude) {
    var lat = finiteNumber(latitude)
    var lon = finiteNumber(longitude)
    return lat !== null && lon !== null && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
}

function buildForecastUrl(latitude, longitude) {
    return "https://api.open-meteo.com/v1/forecast"
        + "?latitude=" + encodeURIComponent(String(latitude))
        + "&longitude=" + encodeURIComponent(String(longitude))
        + "&current=temperature_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m,surface_pressure"
        + "&hourly=precipitation_probability,precipitation,weather_code,wind_speed_10m,wind_gusts_10m,pressure_msl"
        + "&daily=sunrise,sunset,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max"
        + "&forecast_days=1&timezone=auto"
}

function buildMarineUrl(latitude, longitude) {
    return "https://marine-api.open-meteo.com/v1/marine"
        + "?latitude=" + encodeURIComponent(String(latitude))
        + "&longitude=" + encodeURIComponent(String(longitude))
        + "&current=wave_height,wave_direction,wave_period,sea_surface_temperature"
        + "&hourly=wave_height,wave_direction,wave_period,swell_wave_height"
        + "&forecast_days=1&timezone=auto"
}

function weatherLabel(code) {
    var labels = {
        0: "Clear",
        1: "Mainly clear",
        2: "Partly cloudy",
        3: "Overcast",
        45: "Fog",
        48: "Rime fog",
        51: "Light drizzle",
        53: "Drizzle",
        55: "Heavy drizzle",
        61: "Light rain",
        63: "Rain",
        65: "Heavy rain",
        71: "Light snow",
        73: "Snow",
        75: "Heavy snow",
        80: "Rain showers",
        81: "Rain showers",
        82: "Heavy showers",
        95: "Thunderstorm",
        96: "Thunderstorm with hail",
        99: "Severe thunderstorm"
    }
    return labels[code] || "Unknown conditions"
}

function directionLabel(degrees) {
    var value = finiteNumber(degrees)
    if (value === null)
        return ""
    var directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    return directions[Math.round((((value % 360) + 360) % 360) / 45) % 8]
}

function decodeForecast(payload) {
    var current = payload && payload.current
    if (!current)
        return null

    var temperature = finiteNumber(current.temperature_2m)
    var wind = finiteNumber(current.wind_speed_10m)
    var code = finiteNumber(current.weather_code)
    if (temperature === null || wind === null || code === null)
        return null

    var daily = payload.daily || {}
    return {
        temperatureC: temperature,
        apparentTemperatureC: finiteNumber(current.apparent_temperature),
        precipitationMm: finiteNumber(current.precipitation),
        weatherCode: code,
        weatherLabel: weatherLabel(code),
        windKph: wind,
        windDirection: directionLabel(current.wind_direction_10m),
        pressureHpa: finiteNumber(current.surface_pressure),
        sunrise: Array.isArray(daily.sunrise) ? daily.sunrise[0] || "" : "",
        sunset: Array.isArray(daily.sunset) ? daily.sunset[0] || "" : "",
        timezone: typeof payload.timezone === "string" ? payload.timezone : ""
    }
}

function decodeMarine(payload) {
    var current = payload && payload.current
    if (!current)
        return null

    var waveHeight = finiteNumber(current.wave_height)
    var wavePeriod = finiteNumber(current.wave_period)
    var waterTemperature = finiteNumber(current.sea_surface_temperature)
    if (waveHeight === null && wavePeriod === null && waterTemperature === null)
        return null

    return {
        waveHeightM: waveHeight,
        waveDirection: directionLabel(current.wave_direction),
        wavePeriodS: wavePeriod,
        waterTemperatureC: waterTemperature
    }
}

function conditionSummary(forecast, marine, settings) {
    if (!forecast)
        return { level: "unavailable", label: "Unavailable", factors: ["Weather data is unavailable."] }

    var windLimit = finiteNumber(settings && settings.windCautionKph)
    var waveLimit = finiteNumber(settings && settings.waveCautionM)
    windLimit = windLimit === null ? 25 : windLimit
    waveLimit = waveLimit === null ? 1.5 : waveLimit
    var factors = []
    var caution = false
    var unsafe = false

    if (forecast.weatherCode >= 95) {
        unsafe = true
        factors.push("Thunderstorm conditions are forecast.")
    }
    if (forecast.windKph >= windLimit * 1.5) {
        unsafe = true
        factors.push("Wind is above the configured comfort limit.")
    } else if (forecast.windKph >= windLimit) {
        caution = true
        factors.push("Wind is near the configured comfort limit.")
    } else {
        factors.push("Wind is within the configured comfort limit.")
    }
    if (marine && marine.waveHeightM !== null) {
        if (marine.waveHeightM >= waveLimit * 1.5) {
            unsafe = true
            factors.push("Wave height is above the configured comfort limit.")
        } else if (marine.waveHeightM >= waveLimit) {
            caution = true
            factors.push("Wave height is near the configured comfort limit.")
        } else {
            factors.push("Wave height is within the configured comfort limit.")
        }
    }
    if (forecast.precipitationMm !== null && forecast.precipitationMm > 2) {
        caution = true
        factors.push("Precipitation is currently reported by the forecast.")
    }
    if (!unsafe && !caution)
        return { level: "good", label: "Favorable", factors: factors }
    if (unsafe)
        return { level: "unsafe", label: "Use caution", factors: factors }
    return { level: "caution", label: "Mixed", factors: factors }
}

function formatTemperature(celsius, units) {
    if (celsius === null || celsius === undefined)
        return "—"
    return units === "imperial"
        ? Math.round(celsius * 9 / 5 + 32) + " °F"
        : Math.round(celsius) + " °C"
}

function formatWind(kph, units) {
    if (kph === null || kph === undefined)
        return "—"
    return units === "imperial"
        ? Math.round(kph * 0.621371) + " mph"
        : Math.round(kph) + " km/h"
}

function formatWave(meters, units) {
    if (meters === null || meters === undefined)
        return "—"
    return units === "imperial"
        ? (meters * 3.28084).toFixed(1) + " ft"
        : meters.toFixed(1) + " m"
}

function haversineMeters(latitudeA, longitudeA, latitudeB, longitudeB) {
    var radians = Math.PI / 180
    var deltaLatitude = (latitudeB - latitudeA) * radians
    var deltaLongitude = (longitudeB - longitudeA) * radians
    var a = Math.sin(deltaLatitude / 2) * Math.sin(deltaLatitude / 2)
        + Math.cos(latitudeA * radians) * Math.cos(latitudeB * radians)
        * Math.sin(deltaLongitude / 2) * Math.sin(deltaLongitude / 2)
    return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}
