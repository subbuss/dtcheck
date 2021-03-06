require 'json'
require 'pp'
require 'cgi'
require 'date'

def html name, text = nil, **attrs, &contents
	attrs_str = attrs.select{|k,v| v}.map{|k,v| " #{CGI.escapeHTML k.to_s}=\"#{CGI.escapeHTML v.to_s}\"" }.join ''
	s = ''
	s += "<#{CGI.escapeHTML name}#{attrs_str}>" if name
	s += CGI.escapeHTML text.to_s if text
	s += contents.call.to_s if contents
	s += "</#{CGI.escapeHTML name}>" if name
	return s
end

def percent a, b
	b === 0 ? '' : "#{(a.to_f/b*100).round(1)}%"
end

database = JSON.parse(File.read('database.json'), symbolize_names: true)

puts '<meta charset="utf-8">'
puts '<link rel="stylesheet" type="text/css" href="styles.css">'
puts '<link rel="stylesheet" type="text/css" href="styles-mw.css">'

title = "Reply tool check statistics"
puts html('title', title)
puts html('h1', title)

headers = []
rows = database[:sites].keys.map{|site| [site, []] }.to_h

oldest_rev = database[:sites].values.map{|data| data[:revisions].values }.inject(:+).map{|a| a[:timestamp] }.min

Date.strptime(oldest_rev).upto(Date.today).reverse_each do |day|
	headers << day.iso8601
	database[:sites].each do |site, data|
		rows[site] << {
			total:      data[:revisions].values.select{|r| r[:timestamp].start_with? day.iso8601 }.length,
			suspicious: data[:revisions].values.select{|r| r[:timestamp].start_with? day.iso8601 }.count{|r| r[:suspicious] }
		}
	end
end

puts html('p', "Choose rows:")
row_info = {
	'sus'   => true,
	'good'  => false,
	'total' => true,
	'suspc' => false,
}
row_info.each do |rowtype, active|
	puts html('style', media: active ? 'not all' : 'all'){ "tr.#{rowtype} > *:not([rowspan]) { display: none; }" }
	onchange = "this.parentNode.previousElementSibling.media = this.checked ? 'not all' : 'all';"
	puts html('label'){
		html('input', type: 'checkbox', checked: active, onchange: onchange) + ' ' +
		html(nil, rowtype)
	}
end

puts '<table class="wikitable statistics">'
puts '<tr>'
puts html('th', "Site", colspan: 2)
puts html('th', "All days", class: 'summary')
headers.each{|h| puts html('th'){ html 'a', h, href: "dtcheck-#{h}.html" } }
puts '</tr>'

out = []
rows.each do |site, data|
	suspicious = data.reduce(0) {|sum,d| sum + d[:suspicious] }
	total = data.reduce(0) {|sum,d| sum + d[:total] }
  [
    { type: "sus",   data: suspicious,                 proc: Proc.new { |d| d[:suspicious] }, rowspan: 4, },
    { type: "good",  data: total - suspicious,         proc: Proc.new { |d| d[:total] - d[:suspicious] },
    { type: "total", data: total,                      proc: Proc.new { |d| d[:total] } },
    { type: "suspc", data: percent(suspicious, total), proc: Proc.new { |d| percent(d[:suspicious], d[:total]) } },
  ].each do |info|
    out << "<tr class='#{info[:type]}'>"
    if (info[:rowspan]) {
	    out << html('th', site, rowspan: info[:rowspan])
    }
	  out << html('th', info[:type])
	  data.each{|d| out << html('td', info[:proc].call(d))
	  out << '</tr>'
 end
end

suspicious = headers.length.times.map{|i| rows.reduce(0) {|sum, site, r| sum + r[i][:suspicious] } }
total = headers.length.times.map{|i| rows.reduce(0) {|sum, site, r| sum + r[i][:total] } }

puts '<tr class="sus">'
puts html('th', "All sites", rowspan: 4, class: 'summary')
puts html('th', "sus", class: 'summary')
puts html('td', suspicious.inject(:+), class: 'summary')
suspicious.each{|s| puts html('td', s) }
puts '</tr>'
puts '<tr class="good">'
puts html('th', "good", class: 'summary')
puts html('td', total.inject(:+) - suspicious.inject(:+), class: 'summary')
suspicious.zip(total).each{|s, t| puts html('td', t - s) }
puts '</tr>'
puts '<tr class="total">'
puts html('th', "total", class: 'summary')
puts html('td', total.inject(:+), class: 'summary')
total.each{|s| puts html('td', s) }
puts '</tr>'
puts '<tr class="suspc">'
puts html('th', "suspc", class: 'summary')
puts html('td', percent(suspicious.inject(:+), total.inject(:+)), class: 'summary')
suspicious.zip(total).each{|s, t| puts html('td', percent(s, t)) }
puts '</tr>'

puts out.join("\n")

puts '</table>'

puts html('p', "Generated at #{database[:last_updated]} in #{(database[:last_updated_duration]).ceil} seconds.")
puts html('p'){ html('a', 'Source code', href: "https://github.com/MatmaRex/dtcheck") }
