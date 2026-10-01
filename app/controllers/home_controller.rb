class HomeController < ApplicationController
  def index
    @categories = Category.alphabetical.includes(:services)
    @stylists = Stylist.alphabetical.with_attached_photo
  end

  def stylist
    @stylist = Stylist.find(params[:id])
    @date = parse_date(params[:date]) || Date.current
    @slots = @stylist.available_slots(@date)
  end

  private

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end
end
