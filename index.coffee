#
# Connection monitoring widget for OSX
#
# To style this thing, search for "style:" and modify the css in there.  The HTML structure
# is in the "render:" property.
#
# TODO Add a control to hide google domains (1e100.net)
# TODO Add a control to hide localhost
# TODO Add a control to reset / reload
# TODO Make connections and hosts list scroll like a ticker if there's overflow
# TODO Make it less ugly
#

# Call ifconfig for inteface info
# Call lsof for connection info
# Filter out stuff bound to localhost
#
# lsof options:
#   -i 4 -> shows IPv4 only
#   -R   -> shows parent pid
#   +c 0 -> show as much of command as possible
#   -n   -> don't lookup ip hostnames (slow if turned on)
#   -P   -> don't map port #'s to protocols
command: "echo 'IFACES' && ifconfig && echo 'CONNECTIONS' && lsof -i 4 -R +c 0 -n -P | grep -v 127.0.0.1"
# command: "echo 'IFACES' && ifconfig && echo 'CONNECTIONS' && lsof -i 4 -R +c 0 -n -P"

# the refresh frequency in milliseconds
refreshFrequency: 5000

# Just creates structure of the page
render: (output) -> 
  localStorage.clear()
  """
<div id="hosts_container">
  <h1>Connected Hosts</h1>
  <table id="hosts_table">
    <thead><tr><th>Address</th><th>Host</th></tr></thead>
    <tbody></tbody>
  </table>
</div>

<div id="interfaces_container">
  <h1>Active Interfaces</h1>
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

# the CSS style for this widget, written using Stylus
# (http://learnboost.github.io/stylus/)
style: """
  box-sizing: border-box
  padding: 0px 0px
  margin: 0px 0px
  color: #fff
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

  table
    padding: 0px 0px
    margin: 0px 0px

    th
      font-weight: 400
      font-family: Helvetica Neue
    td
      font-family: Consolas
      font-size: 12px
    tbody
      overflow: auto

  #hosts_container
    position: fixed
    top: 0px
    left: 0px
    width: 400px

  #interfaces_container
    position: fixed
    left: 0px
    bottom: 0px
    width: 400px

  #connections_container
    position: fixed
    top: 0px
    left: 450px
    width: 100%
"""

#
# Gets called every @refreshFrequency
# @param output -> the result of running @command
# @param dom    -> the dom of the page (basically the result of render)
#
update: (output, dom) ->
  #
  # Splice up output of command
  #
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

  # Kill whitespace, break into array of lines
  lines = output.replace(/\ +/g,' ').split('\n')
  # Interface info is between line beginning with IFACES and before CONNECTIONS
  ifaces = lines.slice(lines.indexOf('IFACES')+1, lines.indexOf('CONNECTIONS'))
  # Connection info is starts with line beginning with CONNECTIONS until the end
  connections = lines.slice(lines.indexOf('CONNECTIONS')+1)

  #
  # Parse output of ifconfig
  # @returns Map<ip, interface>
  #
  ipToInterfaceMap = new Map
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
      ipToInterfaceMap.set(ip, iface)

  @updateIpInterfaceMap(ipToInterfaceMap)

  #
  # Parse output of lsof into an object
  # @returns Descriptor[]
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

  #
  # Get unique list of connected IPs
  # @return ip[]
  #
  ips = []
  for descriptor in descriptors
    hasIp = descriptor.name.match(/->([0-9][^:]*)/)
    if hasIp? && ips.indexOf(hasIp[1]) < 0
      ips.push(hasIp[1])

  @feedDnsCache(ips)

  @renderHosts(dom, ips)

  @renderInterfaces(dom, ipToInterfaceMap)

  @renderConnections(dom, descriptors)

  return

#
# Utility functions
#

#
# Stick the map of ip's to interfaces in localstorage
#
updateIpInterfaceMap: (ipToInterfaceMap) ->
  parentScope = this
  ipToInterfaceMap.forEach (iface, ip, map) ->
    if !localStorage.getItem('iface_' + ip)?
      localStorage.setItem('iface_' + ip, iface)

#
#
#
resolveInterface: (ip) ->
  iface = localStorage.getItem('iface_' + ip)
  if !iface?
    iface = ip
  return iface

#
# Update dns cache in localstorage
#
feedDnsCache: (ips) ->
  parentScope = this
  ips.forEach (ip) ->
    # Only look up stuff 
    if !localStorage.getItem('dns_' + ip)?
      cmd = "dig +noall +answer -x " + ip + " | head -n 1 | awk '{print $5}' | sed 's/\\. *$//'"
      parentScope.run cmd, (err, output) ->
        if output == ""
          output = ip
        localStorage.setItem('dns_' + ip, output)

#
# Resolve an ip to and dns name
# @return name from a reverse dns lookup or the ip if it's not found
resolveIp: (ip) ->
  name = localStorage.getItem('dns_' + ip)
  console.log("RESOLVE ip: " + ip + " name: " + name)
  if !name?
    name = ip
  return name

#
# Display connected ip addresses
#
renderHosts: (dom, ips) ->
  html = ''
  for ip in ips
    html += '<tr>'
    html += '<td>' + ip + '</td>'
    html += '<td id="ip_' + ip.replace(/\./g, '-') + '">' + @resolveIp(ip) + '</td>'
    html += '</tr>'
  $(dom).find("#hosts_table").find("tbody").empty().append(html)

#
# Display interfaces
#
renderInterfaces: (dom, ipToInterfaceMap) ->
  html = ''
  ipToInterfaceMap.forEach (iface, ip) ->
    html += '<tr><td>' + iface + '</td><td>' + ip + '</td></tr>'
  table = $(dom).find("#interfaces_table").find("tbody").empty().append(html)

#
# Update the DOM with the connection info
#
renderConnections: (dom, descriptors) ->
  columnHeaders = ['Command', 'PID', 'PPID', 'User', 'Type', 'Connection', 'State']
  table = $(dom).find("#connections_table")
  html = '<tr>'
  for header in columnHeaders
    html += '<th>' + header + '</th>'
  html += '</tr>'
  table.find("thead").empty().append(html)

  html = ''
  lookupName = ''
  previousPid = 0
  for descriptor in descriptors
    # Create connection info from descriptor name field
    connectionInfo = descriptor.name
    hasSrcIp = descriptor.name.match(/^([0-9][^:]*)/)
    if hasSrcIp?
      interfaceName = @resolveInterface(hasSrcIp[1])
      connectionInfo = connectionInfo.replace(hasSrcIp[1], interfaceName)
    hasDstIp = descriptor.name.match(/->([0-9][^:]*)/)
    if hasDstIp?
      lookupName = @resolveIp(hasDstIp[1])
      connectionInfo = connectionInfo.replace(hasDstIp[1], lookupName)

    # Suppress output on a duplicate PID
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

    html += '<td>' + connectionInfo + '</td>'

    html += '<td>' + descriptor.status + '</td>'
    html += '</tr>'
  table.find("tbody").empty().append(html)


