import React, { useState } from 'react';
import { useEffect } from 'react';
import { Users, Medal, Calendar, X } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { usePartnerStore } from '../../store/partnerStore';

interface PartnerCardProps {
  id: string;
  name: string;
  username: string;
  workoutCount: number;
  joinedDate: string;
  status: 'pending' | 'accepted' | 'rejected'; 
  direction: 'sent' | 'received' | 'accepted';
  onCancel?: () => void;
  onAccept?: () => void;
  onDecline?: () => void;
}

export function PartnerCard({
  id,
  name,
  username,
  workoutCount,
  joinedDate,
  status,
  direction,
  onCancel,
  onAccept,
  onDecline
}: PartnerCardProps) {
  const navigate = useNavigate();
  const [showDebug, setShowDebug] = useState(false);
  const { stats, loadPartnerStats } = usePartnerStore();
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (status === 'accepted') {
      const loadStats = async () => {
        setIsLoading(true);
        try {
          await loadPartnerStats(id);
        } catch (err) {
          console.error('Failed to load partner stats:', err);
        } finally {
          setIsLoading(false);
        }
      };
      loadStats();
    }
  }, [id, status]);

  const statusColors = {
    pending: 'text-orange-400',
    accepted: 'text-green-400',
    rejected: 'text-red-400'
  };

  return (
    <div 
      className="p-6 bg-white/5 backdrop-blur-sm rounded-lg border border-blue-500/10 cursor-pointer hover:border-blue-500/30 transition-colors"
      onClick={(e) => {
        e.preventDefault();
        setShowDebug(true);
        if (status === 'accepted') {
          navigate(`/partners/${id}`);
        }
      }}
    >
      {/* Debug Modal */}
      {showDebug && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50" onClick={() => setShowDebug(false)}>
          <div className="bg-black/90 border border-blue-500/10 rounded-lg p-6 max-w-md w-full mx-4" onClick={e => e.stopPropagation()}>
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-xl font-semibold text-white">Debug Info</h3>
              <button onClick={() => setShowDebug(false)} className="text-gray-400 hover:text-white">
                <X className="w-6 h-6" />
              </button>
            </div>
            <div className="space-y-2">
              <p className="text-gray-400">Partner ID: <span className="text-white font-mono">{id}</span></p>
              <p className="text-gray-400">Status: <span className="text-white">{status}</span></p>
              <p className="text-gray-400">Direction: <span className="text-white">{direction}</span></p>
            </div>
          </div>
        </div>
      )}

      <div className="flex items-center space-x-4 mb-4">
        <div className="w-12 h-12 rounded-full bg-blue-500/20 flex items-center justify-center">
          <Users className="w-6 h-6 text-blue-500" />
        </div>
        <div>
          <h3 className="text-lg font-semibold text-white">
            {name}
          </h3>
          <div className="flex items-center space-x-2">
            <span className="text-sm text-gray-400">@{username}</span>
            <span className={`text-sm ${statusColors[status]}`}>
              {direction === 'accepted' ? '' : 
               direction === 'sent' ? `Invite ${status}` : 
               status.charAt(0).toUpperCase() + status.slice(1)}
            </span>
          </div>
        </div>
      </div>
      
      <div className="space-y-2">
        <div className="flex items-center space-x-2">
          <Medal className="w-4 h-4 text-blue-400" />
          <span className="text-gray-300">
            <span className="text-gray-400">Partner Stats Coming Soon!</span>
          </span>
        </div>
        <div className="flex items-center space-x-2">
          <Calendar className="w-4 h-4 text-green-400" />
          <span className="text-gray-300">Joined {new Date(joinedDate.replace(/-/g, '/')).toLocaleDateString()}</span>
        </div>
      </div>

      {status === 'pending' && direction === 'received' && (
        <div className="mt-4 flex space-x-2">
          <button
            onClick={(e) => {
              e.stopPropagation();
              onAccept?.();
            }}
            className="flex-1 py-2 bg-green-500 text-white rounded-lg font-medium hover:bg-green-600 transition-colors"
          >
            Accept
          </button>
          <button
            onClick={(e) => {
              e.stopPropagation();
              onDecline?.();
            }}
            className="flex-1 py-2 bg-red-500 text-white rounded-lg font-medium hover:bg-red-600 transition-colors"
          >
            Decline
          </button>
        </div>
      )}
      
      {status === 'pending' && direction === 'sent' && (
        <div className="mt-4">
          <button
            onClick={(e) => {
              e.stopPropagation();
              onCancel?.();
            }}
            className="w-full py-2 bg-red-500 text-white rounded-lg font-medium hover:bg-red-600 transition-colors"
          >
            Cancel Invite
          </button>
        </div>
      )}
    </div>
  );
}