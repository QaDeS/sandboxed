require 'sandboxed'

class Ctx
  attr_reader :log
  def initialize
    @log = []
  end

  def internal_log(text)
    @log << text
  end

  def sandbox_log(text)
    @log << text
  end
  safe_method :sandbox_log
end

describe Kernel do
  describe "#safe" do
    it "should use :level => 4 as default" do
      safe { $SAFE }.should == 4
    end
    it "should execute safe operations" do
      safe { 2 + 2 }.should == 4
    end
    it "should not execute unsafe operations" do
      lambda{ safe{puts 'foo'} }.should raise_error SecurityError
    end
    it "should allow access depending on the :level" do
      lambda{ safe(:level => 0){'foo'.taint} }.should_not raise_error SecurityError
    end
    it "should execute on the context object" do
      safe(:context => 'foo'){ reverse }.should == 'oof'
    end
    it "should pass in safe local variables" do
      arr = [].untrust
      safe(arr){ |a| a << 'foo'}.should == ['foo']
      arr.should == ['foo']
    end
    it "should pass in unsafe local variables" do
      arr = []
      lambda{ safe(arr){|a| a << 'foo'} }.should raise_error SecurityError
      arr.should == []
    end
    it "should pass in hash local variables and options" do
      safe(:from => 2, :len => 3, :context => 'foobar'){ |h| self[h[:from],h[:len]] }.should == 'oba'
    end
  end

  describe "#safe_method" do
    before(:each) do
      @ctx = Ctx.new
    end

    it "should not execute unsafe methods" do
      lambda{ safe(:context => @ctx){internal_log 'foo'} }.should raise_error SecurityError
    end
    it "should execute safe methods" do
      safe(:context => @ctx){sandbox_log 'foo'}.should == ['foo']
    end  
  end

end
