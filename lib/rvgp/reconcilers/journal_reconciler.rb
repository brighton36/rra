# frozen_string_literal: true

require_relative '../journal'

module RVGP
  module Reconcilers
    # This reconciler is instantiated for input files of type journal (Plain Text Accounting text files).
    # There are no parameters to this Reconciler, that aren't already documented in {RVGP::Reconcilers}
    class JournalReconciler < RVGP::Base::Reconciler
      private

      def journal
        RVGP::Journal.parse File.read(input_file)
      end

      def source_postings
        @source_postings ||= journal.postings.map do |posting|
          unless posting.transfers.first.commodity && posting.transfers.last.commodity.nil?
            raise StandardError, format('Unimplemented posting on: %<file>s:%<line_no>d',
                                        file: input_file, line_no: posting.line_number)
          end

          # For Journal:Posting's with multiple account transfer lines, we break it into
          # multiple RVGP::Base::Reconciler::Posting postings.
          posting.transfers[0...-1].map do |transfer|
            # NOTE: The tags.dup appears to be needed, because otherwise the
            #       tags array ends up shared between the two entries, and
            #       operations on one, appear in the other's contents
            RVGP::Base::Reconciler::Posting.new posting.line_number,
                                                date: posting.date,
                                                tags: posting.tags.dup,
                                                from: from,
                                                description: posting.description,
                                                commodity: transform_commodity(transfer.commodity),
                                                to: transfer.account
          end
        end.flatten
      end
    end
  end
end
