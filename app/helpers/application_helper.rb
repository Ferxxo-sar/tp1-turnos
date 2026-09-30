module ApplicationHelper
  def business_name
    Rails.configuration.x.business_name
  end

  def status_badge(status)
    tag.span(Appointment.status_label(status), class: [ "badge", status ])
  end

  def money(amount)
    number_to_currency(amount)
  end

  def avatar_for(stylist, size: nil)
    classes = [ "avatar", size ].compact
    if stylist.photo.attached?
      image_tag stylist.photo, alt: stylist.name, class: classes
    else
      tag.span(stylist.initials, class: classes, aria: { hidden: true })
    end
  end

  def nav_link(label, path, exact: false)
    active = exact ? current_page?(path) : request.path.start_with?(path)
    link_to label, path, class: ("active" if active)
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
