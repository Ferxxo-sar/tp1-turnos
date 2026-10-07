module ApplicationHelper
  # Íconos de trazo (estilo Lucide) dibujados inline para no sumar dependencias.
  ICONS = {
    home: '<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V21h14V9.5"/>',
    calendar: '<rect x="3" y="4.5" width="18" height="16.5" rx="2"/><path d="M3 9.5h18M8 2.5v4M16 2.5v4"/>',
    list: '<path d="M9 6h12M9 12h12M9 18h12"/><path d="M4 6h.01M4 12h.01M4 18h.01"/>',
    users: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.8-3.6 3.4-5.5 6.5-5.5s5.7 1.9 6.5 5.5"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18.5 14.8c1.6.8 2.6 2.6 3 5.2"/>',
    scissors: '<circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><path d="M8.1 8.1 20 20M8.1 15.9 20 4"/>',
    tag: '<path d="M3 12V3h9l9 9-9 9z"/><circle cx="7.5" cy="7.5" r="1.5"/>',
    folder: '<path d="M3 6.5A1.5 1.5 0 0 1 4.5 5H9l2 2.5h8.5A1.5 1.5 0 0 1 21 9v9.5a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 18.5z"/>',
    chart: '<path d="M3 3v18h18"/><path d="M7.5 16v-4M12 16V8M16.5 16v-6"/>',
    shield: '<path d="M12 3 4.5 6v6c0 4.5 3.2 7.8 7.5 9 4.3-1.2 7.5-4.5 7.5-9V6z"/>',
    logout: '<path d="M15 4h4a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-4"/><path d="M10 17l-5-5 5-5M5 12h11"/>',
    external: '<path d="M14 4h6v6M20 4l-9 9"/><path d="M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/>',
    download: '<path d="M12 4v11M7 10l5 5 5-5M4 20h16"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    left: '<path d="M15 18l-6-6 6-6"/>',
    right: '<path d="M9 18l6-6-6-6"/>'
  }.freeze

  def icon(name, size: 18)
    tag.svg(ICONS.fetch(name).html_safe, class: "icon", width: size, height: size, viewBox: "0 0 24 24",
            fill: "none", stroke: "currentColor", "stroke-width": 1.75, "stroke-linecap": "round",
            "stroke-linejoin": "round", aria: { hidden: true })
  end

  def business_name
    Rails.configuration.x.business_name
  end

  def status_badge(status)
    tag.span(Appointment.status_label(status), class: [ "badge", status ])
  end

  def money(amount, precision: 2)
    number_to_currency(amount, precision: precision)
  end

  def avatar_for(stylist, size: nil)
    classes = [ "avatar", size ].compact
    if stylist.photo.attached?
      image_tag stylist.photo, alt: stylist.name, class: classes
    else
      tag.span(stylist.initials, class: classes, aria: { hidden: true })
    end
  end

  def nav_link(label, path, exact: false, icon: nil)
    active = exact ? current_page?(path) : request.path.start_with?(path)
    link_to path, class: ("active" if active), aria: { current: ("page" if active) } do
      safe_join([ (icon(icon) if icon), tag.span(label) ].compact)
    end
  end

  # Variación porcentual contra un valor anterior, para las tarjetas de KPI.
  def delta_tag(current, previous)
    return tag.span("sin datos del mes anterior", class: "delta") if previous.to_d.zero?

    change = ((current.to_d - previous.to_d) / previous.to_d * 100).round
    tag.span("#{change.positive? ? '+' : ''}#{change}% vs. mes anterior",
             class: [ "delta", (change.negative? ? "down" : "up") ])
  end

  def error_messages_for(record)
    return if record.errors.empty?

    tag.div(class: "errors", role: "alert") do
      tag.strong("Revisá los siguientes datos:") +
        tag.ul { safe_join(record.errors.full_messages.map { |message| tag.li(message) }) }
    end
  end

  def duration(minutes)
    hours, mins = minutes.divmod(60)
    return "#{mins} min" if hours.zero?

    mins.zero? ? "#{hours} h" : "#{hours} h #{mins} min"
  end

  def date_chip(time)
    tag.div(class: "date-chip") do
      tag.span(l(time, format: "%b"), class: "m") + tag.span(time.day, class: "d")
    end
  end
end
