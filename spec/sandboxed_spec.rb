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

def self_method
  'self'
end

describe Sandboxed do
  describe "#default_mode" do
    before(:each) { @default_mode = Sandboxed.default_mode }
    after(:each) { Sandboxed.default_mode = @default_mode }

    it "should be in :bound mode per default" do
      Sandboxed.default_mode.should == :bound
      ctx = Ctx.new
      safe(:context => ctx){ self }.should == ctx
    end

    it "should switch into :overlay mode" do
      Sandboxed.default_mode = :overlay
      ctx = Ctx.new
      safe(:context => ctx){ self_method }.should == 'self'
   end

    it "should be overridable by the :mode option" do
      Sandboxed.default_mode = :overlay
      ctx = Ctx.new
      safe(:mode => :bound, :context => ctx){ self }.should == ctx
      Sandboxed.default_mode.should == :overlay # change should not be permanent
    end

  end
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
      arr = []
      lambda{ safe{arr << 'foo'} }.should raise_error(SecurityError)
    end

    it "should allow access depending on the :level" do
      arr = []
      lambda{ safe(:level => 0){arr << 'foo'} }.should_not raise_error(SecurityError)
    end

    it "should execute methods on the context object" do
      safe(:context => 'foo'){ reverse }.should == 'oof'
    end

    it "should pass in safe local variables" do
      arr = [].untrust
      safe{ arr << 'foo'}.should == ['foo']
      arr.should == ['foo']
    end

    it "should pass in unsafe local variables" do
      arr = []
      lambda{ safe{arr << 'foo'} }.should raise_error(SecurityError)
      arr.should == []
    end

    it "should pass in hash parameters and options" do
      safe(:from => 2, :len => 3, :context => 'foobar'){ |h| self[h[:from],h[:len]] }.should == 'oba'
    end

    # overlay mode
    it "should pass in locals in :overlay mode" do
      my_local = "visible"
      safe(:mode => :overlay){ my_local }.should == "visible"
    end
    it "should pass in parameters in :overlay mode" do
      my_param = "visible"
      safe(my_param, :mode => :overlay){ |param| param }.should == "visible"
    end

    # bound mode
    it "should pass in locals in :bound mode" do
      my_local = "visible"
      safe(:mode => :bound){ my_local }.should == "visible"
    end
    it "should pass in parameters in :bound mode" do
      my_param = "visible"
      safe(my_param, :mode => :bound){ |param| param }.should == "visible"
    end
  end # describe "#safe"

  describe "#safe_method" do
    before(:each) do
      @ctx = Ctx.new
    end

    %w(overlay bound).each do |mode|
      it "should not execute unsafe methods in :#{mode} mode" do
        lambda{ safe(:mode => mode, :context => @ctx){internal_log 'foo'} }.should raise_error(SecurityError)
      end
      it "should execute safe methods in :#{mode} mode" do
        safe(:mode => mode, :context => @ctx){sandbox_log 'foo'}.should == ['foo']
      end
    end
  end

end
