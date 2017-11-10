module ApplicationHelper

  def flash_alert(flash)
    alt = flash.to_hash.stringify_keys
    alt["success"] ||= alt.delete("notice")
    alt["danger"]  ||= alt.delete("alert")
    keys = %w(primary secondary success danger warning info light dark)
    return "" unless key = keys.find {|k| alt[k]}
    raw """
    <div class='alert alert-#{key}' role='alert'>#{alt[key]}</div>
    """
  end

  def breadcrumb(list)
    head = list[0..-2].map do |elem|
      lbl, lnk = elem
      "<li class='breadcrumb-item'><a href='#{lnk}'>#{lbl}</a></li>"
    end.join
    lbl = Array(list[-1]).first
    tail = "<li class='breadcrumb-item active' area-current='page'>#{lbl}</li>"
    raw "<ol class='breadcrumb'>#{head}#{tail}</ol>"
  end

  def timestamp
    Time.now.strftime("%H:%M:%S")
  end

  def debug_text
    "<b>#{params["controller"]}##{params["action"]}</b>"
  end

  def nav_text(text)
    raw "<span class='navbar-text'>#{text}</span>"
  end

  def nav_link(label, path, opts = {})

    delopt = opts[:method] == "delete"

    delstr = delopt ? "rel='nofollow' data-method='delete'" : ""

    ext1, ext2 = if current_page?(path) then
      ["active", '<span class="sr-only">(current)</span>']
    else
      ["", ""]
    end

    raw %{
      <li class="nav-item #{ext1}">
        <a class="nav-link" #{delstr} href="#{path}">#{label} #{ext2}</a>
      </li>
    }
  end

  def ttip_content(user)
    obf_count = user.offers_bf.open.count
    obu_count = user.offers_bu.open.count
    """
    <em>#{user.email}</em></br>
    #{obf_count} open #{"ask".pluralize(obf_count)}</br>
    #{obu_count} open #{"bid".pluralize(obu_count)}</br>
    #{user.positions.count} positions</br>
    #{user.balance} balance</br>
    #{user.token_reserve} reserve</br>
    #{user.token_available} available
    """
  end

  def trading_summary(user)
    balance  = user.token_available
    raw "<span class='ttip' data-html='true' data-placement='bottom' title='#{ttip_content(user)}'>#{user.xid} / #{balance} tokens</span>"
  end

end
