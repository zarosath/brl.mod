
Strict

Rem
bbdoc: Networking/Sockets
End Rem
Module BRL.Socket

ModuleInfo "Version: 1.02"
ModuleInfo "Author: Mark Sibly"
ModuleInfo "License: zlib/libpng"
ModuleInfo "Copyright: Blitz Research Ltd"
ModuleInfo "Modserver: BRL"

ModuleInfo "History: 1.02 Release"
ModuleInfo "History: Fixed socket name 0 failing"

Import Pub.StdC

Private

Extern "os"
?Win32
Const FIONREAD=$4004667F
Function ioctl_( socket,opt,buf:Byte Ptr )="int ioctlsocket(SOCKET ,long ,u_long *)!"
?MacOS
Const FIONREAD=$4004667F
Function ioctl_( socket,opt,buf:Byte Ptr )="ioctl"
?Linux
Const FIONREAD=$541b
Function ioctl_( socket,opt,buf:Byte Ptr )="ioctl"
?emscripten
Const FIONREAD=$541b
Function ioctl_( socket,opt,buf:Byte Ptr )="ioctl"
?
End Extern

Public

Type TSocketException
	Method ToString$()
		Return "Internal socket error"
	End Method
End Type

Type TSocket

	Method Send:Size_T( buf:Byte Ptr,count:Size_T,flags=0 )
		Local n:Size_T=send_( _socket,buf,count,flags )
		If n<0 Return 0
		Return n
	End Method

	Method Recv:Size_T( buf:Byte Ptr,count:Size_T,flags=0 )
		Local n:Size_T=recv_( _socket,buf,count,flags )
		If n<0 Return 0
		Return n
	End Method

	Method Close()
		If _socket<0 Return
		If _autoClose closesocket_ _socket
		_socket=-1
		_localIp=""
		_localPort=-1
		_remoteIp=""
		_remotePort=-1
	End Method
	
	Method Connected()
		If _socket<0 Return False
		Local read=_socket
		If select_( 1,Varptr read,0,Null,0,Null,0 )<>1 Or ReadAvail()<>0 Return True
		Close
		Return False
	End Method		
	
	Method Bind( localPort, family:Int = AF_INET_ )
		If bind_( _socket,family,localPort )<0 Return False
		UpdateLocalName
		Return True
	End Method
	
	Method Connect( addrInfo:TAddrInfo )
		If connect_( _socket, addrInfo.infoPtr )<0 Return False
		UpdateLocalName
		UpdateRemoteName
		Return True
	End Method
	
	Method Listen( backlog )
		Return listen_( _socket,backlog )>=0
	End Method
	
	Method Accept:TSocket( timeout )
		Local read=_socket
		If select_( 1,Varptr read,0,Null,0,Null,timeout )<>1 Return
		Local client=accept_( _socket,Null,Null )
		If client>0 Return Create( client )
	End Method
	
	Method ReadAvail()
		Local n
		Local t=ioctl_( _socket,FIONREAD,Varptr n )
		If t<0 Return 0
		Return n
	End Method
	
	Method SetTCPNoDelay( enable )
		Local flag=enable
		setsockopt_( _socket,IPPROTO_TCP,TCP_NODELAY,Varptr flag,4 )
	End Method
	
	Method Socket()
		Return _socket
	End Method
	
	Method LocalIp:String()
		Return _localIp
	End Method
	
	Method LocalPort()
		Return _localPort
	End Method
	
	Method RemoteIp:String()
		Return _remoteIp
	End Method
	
	Method RemotePort()
		Return _remotePort
	End Method
	
	Method UpdateLocalName()
		Local addr:Byte[16],size=16
		If getsockname_( _socket,addr,size )<0
			_localIp=0
			_localPort=0
		EndIf
		_localIp=addr[4] Shl 24 | addr[5] Shl 16 | addr[6] Shl 8 | addr[7]
		_localPort=addr[2] Shl 8 | addr[3]
	End Method
	
	Method UpdateRemoteName()
		Local addr:Byte[16],size=16
		If getpeername_( _socket,addr,size )<0
			_remoteIp=0
			_remotePort=0
			Return
		EndIf
		_remoteIp=addr[4] Shl 24 | addr[5] Shl 16 | addr[6] Shl 8 | addr[7]
		_remotePort=addr[2] Shl 8 | addr[3]
	End Method
	
	Function Create:TSocket( socket,autoClose=True )
		If socket<0 Return
		Local addr:Byte[16],size
		Local t:TSocket=New TSocket
		t._socket=socket
		t._autoClose=autoClose
		t.UpdateLocalName
		t.UpdateRemoteName
		Return t
	End Function
	
	Function CreateUDP:TSocket(family:Int = AF_INET_)
		Local socket=socket_( family,SOCK_DGRAM_,0 )
		If socket>=0 Return Create( socket,True )
	End Function
	
	Function CreateTCP:TSocket(family:Int = AF_INET_)
		Local socket=socket_( family,SOCK_STREAM_,0 )
		If socket>=0 Return Create( socket,True )
	End Function
	
	Field _socket,_autoClose
	
	Field _localIp:String,_localPort
	Field _remoteIp:String,_remotePort
	
End Type

Rem
bbdoc: Create a UDP socket
returns: A new socket
about:
The new socket is not bound to any local or remote address.
End Rem
Function CreateUDPSocket:TSocket()
	Return TSocket.CreateUDP()
End Function

Rem
bbdoc: Create a TCP socket 
returns: A new socket 
about:
The new socket is not bound to any local or remote address.
End Rem
Function CreateTCPSocket:TSocket()
	Return TSocket.CreateTCP()
End Function

Rem
bbdoc: Close a socket
about:
All sockets should eventually be closed. Once closed, a socket can no longer
be used.
End Rem
Function CloseSocket( socket:TSocket )
	socket.Close
End Function

Rem
bbdoc: Bind a socket to a local port
returns: True if successful, otherwise false
about:
If @localPort is 0, a new local port will be allocated. If @localPort is not 0,
#BindSocket will fail if there is already an application bound to @localPort.
End Rem
Function BindSocket( socket:TSocket, localPort, family:Int = AF_INET_)
	Return socket.Bind( localPort, family )
End Function

Rem
bbdoc: Connect a socket to a remote ip and port
returns: True if successful, otherwise false
about:
For both UDP and TCP sockets, #ConnectSocket will fail if the specified
ip address could not be reached.

In the case of TCP sockets, #ConnectSocket will also fail if there is
no application listening at the remote port.
End Rem
Function ConnectSocket( socket:TSocket, addrInfo:TAddrInfo )
	Return socket.Connect( addrInfo )
End Function

Rem
bbdoc: Start listening at a socket 
about:
The specified socket must be a TCP socket, and must already be bound to a local port.
End Rem
Function SocketListen( socket:TSocket,backlog=0 )
	Return socket.Listen( backlog )
End Function

Rem
bbdoc: Accept new connections on a listening socket 
returns: A new socket, or Null if no connection was made in the specified timeout
about:
The specified socket must be a TCP socket, and must be listening.
End Rem
Function SocketAccept:TSocket( socket:TSocket,timeout=0 )
	Return socket.Accept( timeout )
End Function

Rem
bbdoc: Get socket connection status
returns: True if socket is connected
about:
#SocketConnected allows you to determine if a TCP connection is still
alive or has been remotely closed.

#SocketConnected should only be used with TCP sockets that have already
connected via #ConnectSocket or #SocketAccept.
End Rem
Function SocketConnected( socket:TSocket )
	Return socket.Connected()
End Function

Rem
bbdoc: Get number of bytes available for reading from a socket
returns: Number of bytes that may be read without causing the socket to block
End Rem
Function SocketReadAvail( socket:TSocket )
	Return socket.ReadAvail()
End Function

Rem
bbdoc: Get local ip of a socket 
End Rem
Function SocketLocalIP:String( socket:TSocket )
	Return socket.LocalIP()
End Function

Rem
bbdoc: Get local port of a socket 
End Rem
Function SocketLocalPort( socket:TSocket )
	Return socket.LocalPort()
End Function

Rem
bbdoc: Get remote ip of a socket 
End Rem
Function SocketRemoteIP:String( socket:TSocket )
	Return socket.RemoteIP()
End Function

Rem
bbdoc: Get remote port of a socket 
End Rem
Function SocketRemotePort( socket:TSocket )
	Return socket.RemotePort()
End Function

Rem
bbdoc: Convert an ip address to a dotted string
returns: Dotted string version of ip address
End Rem
Function DottedIP$( ip:Int )
	Return (ip Shr 24)+"."+(ip Shr 16 & 255)+"."+(ip Shr 8 & 255 )+"."+(ip & 255)
End Function

Rem
bbdoc: Converts an IP address string into a binary representation.
about: For AF_INET_, @dst should be an Int or 32-bit (4 bytes) in size.
For AF_INET6_, @dst should be 128-bits (16 bytes) in size.
End Rem
Function InetPton:Int(family:Int, src:String, dst:Byte Ptr)
	Return inet_pton_(family, src, dst)
End Function

Rem
bbdoc: Convert a host name to an ip address
returns: Host ip address, or 0 if host not found
End Rem
Function HostIp:String( HostName$, index:Int=0, family:Int = AF_UNSPEC_ )
	If index<0 Return
	Local ips:String[]=HostIps( HostName, family )
	If index < ips.length Then
		Return ips[index]
	End If
End Function

Rem
bbdoc: Get all ip addresses for a host name
returns: Array of host ips, or Null if host not found
End Rem
Function HostIps:String[]( HostName$, family:Int = AF_UNSPEC_ )
	Local addr:TAddrInfo[] = AddrInfo(HostName, , family)
	Local ips:String[] = New String[addr.length]
	For Local i:Int = 0 Until addr.length
		ips[i] = addr[i].HostIp()
	Next
	Return ips
End Function

Rem
bbdoc: Convert a host ip address to a name
returns: Name of host, or Null if host not found
End Rem
Function HostName$( HostIp:String, family:Int = AF_UNSPEC_ )
	Local addr:TAddrInfo[] = AddrInfo(HostIp, , family)
	If addr Then
		Return addr[0].HostName()
	End If
End Function

Rem
bbdoc: Returns an array of TAddrInfo objects.
End Rem
Function AddrInfo:TAddrInfo[](host:String, service:String = "http", family:Int = AF_UNSPEC_)
	Return getaddrinfo_(host, service, family)
End Function

