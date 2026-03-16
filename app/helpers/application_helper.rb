module ApplicationHelper
  def nav_link_to(label, path, mobile: false)
    active = request.path == path
    base = "px-3 py-2 rounded-lg text-sm font-medium"
    base = "block #{base}" if mobile

    active_classes = "#{base} bg-brand-50 text-brand-600"
    inactive_classes = if mobile
      "#{base} text-gray-600 hover:bg-gray-50"
    else
      "#{base} text-gray-600 hover:text-gray-900 hover:bg-gray-50"
    end

    link_to label, path, class: active ? active_classes : inactive_classes
  end
end
