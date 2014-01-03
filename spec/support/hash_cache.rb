class HashCache < Hash
  alias_method :read, :[]
  alias_method :write, :[]=
end
