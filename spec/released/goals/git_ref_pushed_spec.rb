describe Released::Goals::GitRefPushed do
  subject(:goal) do
    described_class.new(config)
  end

  let(:config) do
    {
      'working_dir' => 'local',
      'remote' => 'gitlab',
      'ref' => config_ref,
    }
  end

  let(:config_ref) { 'devel' }

  let!(:local) do
    Git.init('local').tap do |g|
      g.config('user.name', 'Testy McTestface')
      g.config('user.email', 'testface@example.com')

      g.chdir { File.write('hello.txt', 'hi there') }
      g.add('hello.txt')
      g.commit('Add greeting')
      g.branch('devel').checkout
      g.add_tag('1.2.4')
    end
  end

  let!(:remote) do
    Git.init('remote')
  end

  before do
    local.add_remote('gitlab', './remote')
  end

  describe '#achieved?' do
    subject { goal.achieved? }

    context 'pushing branch' do
      context 'not pushed' do
        it { is_expected.not_to be }
      end

      context 'pushed, but not right rev' do
        before do
          goal.try_achieve

          local.chdir { File.write('bye.txt', 'bye now') }
          local.add('bye.txt')
          local.commit('Add farewell')
          local.branch('devel').checkout
        end

        it { is_expected.not_to be }
      end

      context 'pushed' do
        before { goal.try_achieve }
        it { is_expected.to be }
      end
    end

    context 'pushing tag' do
      let(:config_ref) { '1.2.4' }

      context 'not pushed' do
        it { is_expected.not_to be }
      end

      context 'pushed, but not right rev' do
        before do
          goal.try_achieve

          local.chdir { File.write('bye.txt', 'bye now') }
          local.add('bye.txt')
          local.commit('Add farewell')
          local.delete_tag('1.2.4')
          local.add_tag('1.2.4')
        end

        it { is_expected.not_to be }
      end

      context 'pushed' do
        before { goal.try_achieve }
        it { is_expected.to be }
      end
    end
  end

  describe '#try_achieve' do
    subject { goal.try_achieve }

    context 'pushing branch' do
      let(:config_ref) { 'devel' }

      example do
        expect(remote.branches['devel']).to be_nil
        subject
        expect(remote.branches['devel'].gcommit.sha).to eql(local.branches['devel'].gcommit.sha)
      end
    end

    context 'pushing tag' do
      let(:config_ref) { '1.2.4' }

      example do
        expect(remote.tags).to be_empty
        subject
        expect(remote.tag('1.2.4').sha).to eql(local.tag('1.2.4').sha)
      end
    end
  end

  describe '#failure_reason' do
    subject { goal.failure_reason }

    context 'pushed, but not right rev' do
      before do
        goal.try_achieve

        local.chdir { File.write('bye.txt', 'bye now') }
        local.add('bye.txt')
        local.commit('Add farewell')
        local.branch('devel').checkout
      end

      it { is_expected.to match(%r{ref devel \(.{8}\) is not the same as gitlab/devel \(.{8}\)}) }
    end

    context 'not pushed' do
      it { is_expected.to match(/ref devel \(.{8}\) does not exist on remote gitlab/) }
    end
  end
end
