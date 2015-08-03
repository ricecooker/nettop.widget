#
# Connection monitoring widget for OSX
#
# TODO Make dns lookups stateful so we just update new IPs, clear out once a day
# TODO Replace ip addresses in connections with resolved DNS names
# TODO Get a process tree going to reduce dupes
# TODO Something weird with the reverse dns.  Causes screen to flash and the lookup times aren't reflected
#

# Call ifconfig for inteface info
# Call lsof for connection info
# Filter stuff bound to localhost
#
# lsof options:
# -i UDP -> show udp connections
# -P     -> don't resolve port numbers to protocol
# -n     -> 
#
command: "echo 'IFACES' && ifconfig && echo 'CONNECTIONS' && lsof -i TCP -i UDP -R +c 0 -n -P | grep -v 127.0.0.1"

# Sample output:
#
# IFACES
# en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
# 	ether 14:10:9f:dd:73:33
# 	inet6 fe80::1610:9fff:fedd:7333%en0 prefixlen 64 scopeid 0x4
# 	inet 10.0.1.11 netmask 0xffff0000 broadcast 10.0.255.255
# 	nd6 options=1<PERFORMNUD>
# 	media: autoselect
# 	status: active
# en1: flags=8963<UP,BROADCAST,SMART,RUNNING,PROMISC,SIMPLEX,MULTICAST> mtu 1500
# 	options=60<TSO4,TSO6>
# 	ether 32:00:18:be:7b:e0
# 	media: autoselect <full-duplex>
# 	status: inactive
# CONNECTIONS
# COMMAND            PID  PPID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
# HipChat           2041     1 imontoya   24u  IPv4 0x4ab4bbe253c1eb41      0t0  TCP 10.0.1.11:61745->54.166.10.46:5223 (ESTABLISHED)
# Sequel\x20Pro     2124     1 imontoya   17u  IPv4 0x4ab4bbe2505025b1      0t0  TCP 10.0.1.11:61915->10.10.128.75:mysql (ESTABLISHED)
# Sequel\x20Pro     2124     1 imontoya   19u  IPv4 0x4ab4bbe253c1f411      0t0  TCP 10.0.1.11:61917->10.10.128.75:mysql (ESTABLISHED)
# com.apple.WebKi   3497     1 imontoya   19u  IPv4 0x4ab4bbe2502e9271      0t0  TCP 10.0.1.11:62744->198.252.206.25:https (ESTABLISHED)
# com.apple.WebKi   3497     1 imontoya   29u  IPv4 0x4ab4bbe2502e9271      0t0  TCP 10.0.1.11:62744->198.252.206.25:https (ESTABLISHED)
#

# the refresh frequency in milliseconds
refreshFrequency: 5000

# Just creates structure of the page
render: (output) -> """
<div id="stats_container">
  <span id="stats"></span>
</div>

<div id="hosts_container">
  <h1>Connected Hosts</h1>
  <table id="hosts_table">
    <thead><tr><th>Address</th><th>Host</th></tr></thead>
    <tbody></tbody>
  </table>
</div>

<div id="interfaces_container">
  <h1>Interfaces</h1>
  <table id="interfaces_table">
    <thead><tr><th>Interface</th><th>Address</th></tr></thead>
    <tbody></tbody>
  </table>
</div>

<div id="connections_container">
  <h1>Connections</h1>
  <table id="connections_table">
    <thead></thead>
    <tbody></tbody>
  </table>
</div>
"""

# update
#   output -> the result of running @command
#   dom    -> the dom of the page (basically the result of render)
update: (output, dom) ->
  # Benchmarking
  timeStart = (new Date).getTime()

  #
  # Splice up output of command
  #
  # Kill whitespace, break into array of lines
  lines = output.replace(/\ +/g,' ').split('\n')
  # Interface info is between line beginning with IFACES and before CONNECTIONS
  ifaces = lines.slice(lines.indexOf('IFACES')+1, lines.indexOf('CONNECTIONS'))
  # Connection info is starts with line beginning with CONNECTIONS until the end
  connections = lines.slice(lines.indexOf('CONNECTIONS')+1)

  #
  # Parse interfaces  - Parse ifconfig output to map IP addresses (inet) to interface name
  #
  ipMap = new Map
  iface = ''
  ifaces.forEach (line, index, array) ->
    # Pull something like wan0: or eth2:
    hasIface = line.match(/^([a-z]+[0-9]+):/)
    if hasIface?
      iface = hasIface[1]
    # Look for an assigned address inet 128.200.3.1
    hasIp = line.match(/inet6* ([^ ]*)/)
    if hasIp?
      ip = hasIp[1]
      ipMap.set(ip, iface)

  #
  # Parse output of lsof
  #
  Descriptor = (lsofRow) ->
    field = lsofRow.split(' ')
    @process = field[0]
    @pid = field[1]
    @ppid = field[2]
    @user = field[3]
    @fd = field[4]
    @type = field[5]
    @device = field[6]
    @size = field[7]
    @node = field[8]
    @name = field[9]
    if field[10]?
      @status = field[10]
    else
      @status = '-'
    return

  descriptors = []
  connections.forEach (connection, lineNo, array) ->
    if lineNo > 0
      descriptor = new Descriptor(connection)
      descriptors.push(descriptor)
  descriptors.pop() # Last line is empty

  # Benchmark
  timeFinishParse = (new Date).getTime()

  #
  # Pull out IPs to resolve
  #
  ipToNameMap = new Map
  for descriptor in descriptors
    hasIp = descriptor.name.match(/->([0-9][^:]*)/)
    if hasIp? 
      ipToNameMap.set hasIp[1], hasIp[1]

  # Use dig to do reverse dns lookups
  parentScope = this
  ipToNameMap.forEach (name, ip) ->
    cmd = "dig +noall +answer -x " + ip + " | head -n 1 | awk '{print $5}'"
    parentScope.run cmd, (err, output) ->
      if output == ""
        output = ip
      if ipToNameMap.get(ip) != output
        ipToNameMap.set(ip, output)
        element = "#ip_" + ip.replace(/\./g, '-')
        $(dom).find(element).empty().append(output)

  # Benchmark
  timeFinishRdns = (new Date).getTime()

  #
  # Display connected ip addresses
  #
  html = ''
  ipToNameMap.forEach (dns, ip) ->
    html += '<tr>'
    html += '<td>' + ip + '</td>'
    html += '<td id="ip_' + ip.replace(/\./g, '-') + '">' + dns + '</td>'
    html += '</tr>'
  $(dom).find("#hosts_table").find("tbody").empty().append(html)

  #
  # Display interfaces
  #
  html = ''
  ipMap.forEach (iface, ip) ->
    html += '<tr><td>' + iface + '</td><td>' + ip + '</td></tr>'
  table = $(dom).find("#interfaces_table").find("tbody").empty().append(html)


  #
  # Display network connections
  #
  columnHeaders = ['Command', 'PID', 'PPID', 'User', 'Type', 'Connection', 'State']
  table = $(dom).find("#connections_table")
  html = '<tr>'
  for header in columnHeaders
    html += '<th>' + header + '</th>'
  html += '</tr>'
  table.find("thead").empty().append(html)

  html = ''
  previousPid = 0
  for descriptor in descriptors
    if previousPid == descriptor.pid
      html += '<tr>'
      html += '<td>' + '</td>'
      html += '<td>' + '</td>'
      html += '<td>' + '</td>'
      html += '<td>' + '</td>'
    else
      previousPid = descriptor.pid
      html += '<tr>'
      html += '<td>' + descriptor.process + '</td>'
      html += '<td>' + descriptor.pid + '</td>'
      html += '<td>' + descriptor.ppid + '</td>'
      html += '<td>' + descriptor.user + '</td>'
    html += '<td>' + descriptor.node + '</td>'
    found = false
    ipMap.forEach (iface, inet) ->
      if descriptor.name.indexOf(inet) >= 0
        found = true
        html += '<td>' + descriptor.name.replace(inet, iface) + '</td>'
    if !found 
      html += '<td>' + descriptor.name + '</td>'
    html += '<td>' + descriptor.status + '</td>'
    html += '</tr>'
  table.find("tbody").empty().append(html)

  # Benchmark
  timeFinishDom = (new Date).getTime()

  #
  # Timing code
  #
  timeToParse = timeFinishParse - timeStart
  timeToRdns = timeFinishRdns - timeFinishParse
  timeToDom = timeFinishDom - timeFinishRdns
  $(dom).find("#stats").empty().append('Parse: ' + timeToParse + 'ms Lookups: ' + timeToRdns + 'ms Render: ' + timeToDom + 'ms')

  return html

# the CSS style for this widget, written using Stylus
# (http://learnboost.github.io/stylus/)
style: """
  border-radius: 1px
  box-sizing: border-box
  color: #fff
  font-family: Consolas
  font-weight: 300
  line-height: 1.5
  width: 100%
  text-align: justify
  font-size: 14px

  h1
    font-family: Helvetica Neue
    font-size: 16px
    font-weight: 300
    padding: 0px 0px
    margin: 0px 0px

  em
    font-weight: 400
    font-style: normal

  table
    padding: 0px 0px
    margin: 0px 0px

    th
      font-weight: 400
      font-family: Helvetica Neue
    td
      font-family: Consolas
      font-size: 12px

  #hosts_container
    float: right
    width: 30%

  #interfaces_container
    float: right
    width: 20%

  #connections_container
    width: 40%
"""
