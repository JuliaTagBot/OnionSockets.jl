module OnionSockets

using Sockets
using DiffieHellman

import Serialization
import SecureIO
import Multiplexers

import Multiplexers: Line
import SecureIO: SecureSerializer

serialize(io::Union{TCPSocket,IOBuffer},msg) = Serialization.serialize(io,msg)
deserialize(io::Union{TCPSocket,IOBuffer}) = Serialization.deserialize(io)

serialize(io::Line,msg) = Multiplexers.serialize(io,msg)
deserialize(io::Line) = Multiplexers.deserialize(io)

serialize(io::SecureSerializer,msg) = SecureIO.serialize(io,msg)
deserialize(io::SecureSerializer) = SecureIO.deserialize(io)

BallotIOs = Union{TCPSocket,IOBuffer,Line,SecureSerializer} 

Multiplexers.serialize(io::BallotIOs,msg) = serialize(io,msg)
Multiplexers.deserialize(io::BallotIOs) = deserialize(io)

SecureIO.serialize(io::BallotIOs,msg) = serialize(io,msg)
SecureIO.deserialize(io::BallotIOs) = deserialize(io)

import Sockets.connect
import Sockets.accept
import Sockets.TCPServer

function connect(socket::BallotIOs,id,dh::DH)
    send = x-> serialize(socket,x)
    get = () -> deserialize(socket)

    key,ballotid = diffie(send,get,dh)
    sroutersocket = SecureSerializer(socket,key)
    return sroutersocket
end

connect(port,id,dh::DH) = connect(connect(port),id,dh)

function accept(socket::BallotIOs,members,dh::DH)
    send = x -> serialize(socket,x)
    get = () -> deserialize(socket)

    key,unknownid = hellman(send,get,dh)
    #@assert unknownid==nothing

    securesocket = SecureSerializer(socket,key)
    return securesocket
end

accept(socket::BallotIOs,dh::DH) = accept(socket,nothing,dh)
accept(server::TCPServer,members,dh::DH) = accept(accept(server),members,dh)

export connect, accept, serialize, deserialize

end # module
